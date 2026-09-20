# frozen_string_literal: true

require "test_helper"

class Api::V1::UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:family_admin)

    @user.api_keys.active.destroy_all

    @api_key = ApiKey.create!(
      user: @user,
      name: "Test Read-Write Key",
      scopes: [ "read_write" ],
      source: "web",
      display_key: "test_rw_#{SecureRandom.hex(8)}"
    )

    @read_only_api_key = ApiKey.create!(
      user: @user,
      name: "Test Read-Only Key",
      scopes: [ "read" ],
      display_key: "test_ro_#{SecureRandom.hex(8)}",
      source: "mobile"
    )
  end

  # -- Authentication --------------------------------------------------------

  test "reset requires authentication" do
    delete "/api/v1/users/reset"
    assert_response :unauthorized
  end

  test "destroy requires authentication" do
    delete "/api/v1/users/me"
    assert_response :unauthorized
  end

  test "update requires authentication" do
    patch "/api/v1/users/me", params: { first_name: "New" }
    assert_response :unauthorized
  end

  # -- Scope enforcement -----------------------------------------------------

  test "reset requires write scope" do
    delete "/api/v1/users/reset", headers: api_headers(@read_only_api_key)
    assert_response :forbidden
  end

  test "destroy requires write scope" do
    delete "/api/v1/users/me", headers: api_headers(@read_only_api_key)
    assert_response :forbidden
  end

  test "update requires write scope" do
    patch "/api/v1/users/me", params: { first_name: "New" }, headers: api_headers(@read_only_api_key)
    assert_response :forbidden
  end

  # -- Reset -----------------------------------------------------------------


  test "reset requires admin role" do
    non_admin_api_key = ApiKey.create!(
      user: users(:family_member),
      name: "Member Read-Write Key",
      scopes: [ "read_write" ],
      source: "web",
      display_key: "test_member_#{SecureRandom.hex(8)}"
    )

    assert_no_enqueued_jobs only: FamilyResetJob do
      delete "/api/v1/users/reset", headers: api_headers(non_admin_api_key)
    end

    assert_response :forbidden
    body = JSON.parse(response.body)
    assert_equal "You are not authorized to perform this action", body["message"]
  end

  test "reset enqueues FamilyResetJob and returns 200" do
    assert_enqueued_with(job: FamilyResetJob, args: [ @user.family ]) do
      delete "/api/v1/users/reset", headers: api_headers(@api_key)
    end

    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal "Account reset has been initiated", body["message"]
    assert_equal "queued", body["status"]
    assert_equal @user.family.id, body["family_id"]
    assert body["job_id"].present?
    assert_equal "/api/v1/users/reset/status", body["status_url"]
  end

  test "reset returns controlled error when enqueue fails" do
    FamilyResetJob.stub(:perform_later, ->(_family) { raise StandardError, "queue down" }) do
      delete "/api/v1/users/reset", headers: api_headers(@api_key)
    end

    assert_response :internal_server_error
    body = JSON.parse(response.body)
    assert_equal "reset_enqueue_failed", body["error"]
    assert_equal "Account reset could not be queued", body["message"]
    assert_not_includes response.body, "queue down"
  end

  test "reset status requires authentication" do
    get "/api/v1/users/reset/status"
    assert_response :unauthorized
  end

  test "reset status requires admin role" do
    non_admin_api_key = ApiKey.create!(
      user: users(:family_member),
      name: "Member Read Key",
      scopes: [ "read_write" ],
      source: "web",
      display_key: "test_member_read_#{SecureRandom.hex(8)}"
    )

    get "/api/v1/users/reset/status", headers: api_headers(non_admin_api_key)

    assert_response :forbidden
  end

  test "reset status returns family data counts" do
    get "/api/v1/users/reset/status", headers: api_headers(@read_only_api_key)

    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal @user.family.id, body["family_id"]
    assert_includes %w[complete data_remaining], body["status"]
    assert_equal body["counts"].values.sum.zero?, body["reset_complete"]
    assert body["counts"].key?("accounts")
    assert body["counts"].key?("categories")
    assert body["counts"].key?("tags")
    assert body["counts"].key?("merchants")
    assert body["counts"].key?("plaid_items")
    assert body["counts"].key?("imports")
    assert body["counts"].key?("budgets")
  end

  # -- Update account / Onboarding -------------------------------------------

  test "update updates user and family attributes and marks onboarded_at" do
    @user.update!(onboarded_at: nil, set_onboarding_preferences_at: nil, set_onboarding_goals_at: nil, goals: [])
    now_iso = Time.current.iso8601

    patch "/api/v1/users/me", params: {
      first_name: "Juan",
      last_name: "Perez",
      theme: "dark",
      goals: %w[cashflow budgeting],
      set_onboarding_preferences_at: now_iso,
      set_onboarding_goals_at: now_iso,
      onboarded_at: now_iso,
      family_attributes: {
        moniker: "Group",
        name: "Familia Perez",
        country: "PY",
        currency: "PYG",
        locale: "es",
        date_format: "%d/%m/%Y"
      }
    }, headers: api_headers(@api_key), as: :json

    assert_response :ok
    body = JSON.parse(response.body)

    @user.reload
    assert_equal "Juan", @user.first_name
    assert_equal "Perez", @user.last_name
    assert_equal "dark", @user.theme
    assert_equal %w[cashflow budgeting], @user.goals
    assert_not_nil @user.onboarded_at
    assert_equal false, @user.needs_onboarding?

    family = @user.family.reload
    assert_equal "Group", family.moniker
    assert_equal "Familia Perez", family.name
    assert_equal "PY", family.country
    assert_equal "PYG", family.currency
    assert_equal "es", family.locale
    assert_equal "%d/%m/%Y", family.date_format

    assert_equal "Juan", body["current_user"]["first_name"]
    assert_equal "Perez", body["current_user"]["last_name"]
    assert_equal false, body["current_user"]["needs_onboarding"]
    assert_equal false, body["current_user"]["is_invited"]
  end

  test "invited user shows is_invited = true in response" do
    invitation = @user.family.invitations.create!(
      inviter: @user,
      email: "invited@example.com",
      role: "member",
      token: SecureRandom.hex(16),
      accepted_at: Time.current
    )

    invited_user = @user.family.users.create!(
      email: "invited@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: :member
    )

    invited_api_key = ApiKey.create!(
      user: invited_user,
      name: "Invited Key",
      scopes: %w[read_write],
      source: "web",
      display_key: "test_invited_#{SecureRandom.hex(8)}"
    )

    get "/api/v1/family_settings", headers: api_headers(invited_api_key)

    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal true, body["current_user"]["is_invited"]
  end

  # -- Delete account --------------------------------------------------------

  test "destroy deactivates user and returns 200" do
    solo_family = Family.create!(name: "Solo Family", currency: "USD", locale: "en", date_format: "%m-%d-%Y")
    solo_user = solo_family.users.create!(
      email: "solo@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: :admin
    )
    solo_api_key = ApiKey.create!(
      user: solo_user,
      name: "Solo Key",
      scopes: [ "read_write" ],
      source: "web",
      display_key: "test_solo_#{SecureRandom.hex(8)}"
    )

    delete "/api/v1/users/me", headers: api_headers(solo_api_key)
    assert_response :ok

    body = JSON.parse(response.body)
    assert_equal "Account has been deleted", body["message"]

    solo_user.reload
    assert_not solo_user.active?
    assert_not_equal "solo@example.com", solo_user.email
  end

  test "destroy returns 422 when admin has other family members" do
    delete "/api/v1/users/me", headers: api_headers(@api_key)
    assert_response :unprocessable_entity

    body = JSON.parse(response.body)
    assert_equal "Failed to delete account", body["error"]
  end

  # -- Deactivated user ------------------------------------------------------

  test "rejects deactivated user with 401" do
    @user.update_column(:active, false)

    delete "/api/v1/users/reset", headers: api_headers(@api_key)
    assert_response :unauthorized

    body = JSON.parse(response.body)
    assert_equal "Account has been deactivated", body["message"]
  end

  # -- Nav preferences (sincronizado entre dispositivos) ---------------------

  test "nav_preferences requires authentication" do
    get "/api/v1/users/me/nav_preferences"
    assert_response :unauthorized
  end

  test "nav_preferences returns nil when never set" do
    get "/api/v1/users/me/nav_preferences", headers: api_headers(@read_only_api_key)
    assert_response :success

    body = JSON.parse(response.body)
    assert_nil body["nav_item_order"]
  end

  test "update_nav_preferences persists order and syncs across requests" do
    put "/api/v1/users/me/nav_preferences",
        params: { nav_item_order: [ "dashboard", "rules", "goals" ] },
        headers: api_headers(@api_key)
    assert_response :success

    body = JSON.parse(response.body)
    assert_equal [ "dashboard", "rules", "goals" ], body["nav_item_order"]

    get "/api/v1/users/me/nav_preferences", headers: api_headers(@api_key)
    assert_response :success
    assert_equal [ "dashboard", "rules", "goals" ], JSON.parse(response.body)["nav_item_order"]
  end

  test "update_nav_preferences requires write scope" do
    put "/api/v1/users/me/nav_preferences",
        params: { nav_item_order: [ "dashboard" ] },
        headers: api_headers(@read_only_api_key)
    assert_response :forbidden
  end

  test "update_nav_preferences rejects non-array payload" do
    put "/api/v1/users/me/nav_preferences",
        params: { nav_item_order: "not_an_array" },
        headers: api_headers(@api_key)
    assert_response :unprocessable_entity
  end

  # -- Email change (account takeover guard) ----------------------------------

  test "changing the email without the current password is forbidden" do
    original = @user.email

    patch "/api/v1/users/me", params: { email: "attacker@example.com" }, headers: api_headers(@api_key)

    assert_response :forbidden
    assert_equal "password_required", JSON.parse(response.body)["error"]
    assert_equal original, @user.reload.email
    assert_nil @user.unconfirmed_email
  end

  test "changing the email with a wrong password is forbidden" do
    original = @user.email

    patch "/api/v1/users/me",
          params: { email: "attacker@example.com", current_password: "wrong" },
          headers: api_headers(@api_key)

    assert_response :forbidden
    assert_equal original, @user.reload.email
  end

  test "changing the email with the correct password starts the confirmation flow" do
    patch "/api/v1/users/me",
          params: { email: "new-address@example.com", current_password: user_password_test },
          headers: api_headers(@api_key)

    assert_response :success
    @user.reload
    assert(@user.email == "new-address@example.com" || @user.unconfirmed_email == "new-address@example.com")
  end

  test "other profile fields still update without a password" do
    patch "/api/v1/users/me", params: { first_name: "Renamed" }, headers: api_headers(@api_key)

    assert_response :success
    assert_equal "Renamed", @user.reload.first_name
  end

  private

    def api_headers(api_key)
      { "X-Api-Key" => api_key.plain_key }
    end
end
