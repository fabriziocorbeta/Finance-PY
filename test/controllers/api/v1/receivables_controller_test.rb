# frozen_string_literal: true

require "test_helper"

class Api::V1::ReceivablesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:family_admin)
    @family = @user.family

    @user.api_keys.active.destroy_all
    @api_key = ApiKey.create!(
      user: @user,
      name: "Test Read Key",
      scopes: [ "read" ],
      source: "web",
      display_key: "test_read_#{SecureRandom.hex(8)}"
    )

    Redis.new.del("api_rate_limit:#{@api_key.id}")

    @receivable = Receivable.create!(total_amount: 500, due_day: 15)
    @account = @family.accounts.create!(
      name: "Test Receivable",
      balance: 500,
      currency: "USD",
      accountable: @receivable
    )
  end

  test "should list receivables" do
    get api_v1_receivables_url, headers: api_headers(@api_key)
    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response["data"].any? { |r| r["id"] == @receivable.id }
  end

  # Regresion: el scope por familia solo NO alcanza. Dentro de una misma
  # familia, una cuenta pertenece a un usuario (accounts.owner_id) y solo es
  # visible para otros si hay un AccountShare. Sin .accessible_by en
  # receivables_scope, family_admin veia las cuentas a cobrar privadas de
  # family_member. Mismo bug que se corrigio antes en el controller web.
  test "should not list receivables of an account owned by another user in the same family" do
    other_user = users(:family_member)
    private_receivable = Receivable.create!(total_amount: 999, due_day: 10)
    @family.accounts.create!(
      name: "Privada de family_member",
      balance: 999,
      currency: "USD",
      owner: other_user,
      accountable: private_receivable
    )

    get api_v1_receivables_url, headers: api_headers(@api_key)
    assert_response :success

    ids = JSON.parse(response.body)["data"].map { |r| r["id"] }
    assert_includes ids, @receivable.id
    assert_not_includes ids, private_receivable.id
  end

  test "should not list another family's receivables" do
    other_family = Family.create!(name: "Other Family", currency: "USD", locale: "en")
    other_receivable = Receivable.create!(total_amount: 1000)
    other_family.accounts.create!(
      name: "Other Receivable",
      balance: 1000,
      currency: "USD",
      accountable: other_receivable
    )

    get api_v1_receivables_url, headers: api_headers(@api_key)
    assert_response :success

    receivable_ids = JSON.parse(response.body)["data"].map { |r| r["id"] }
    assert_includes receivable_ids, @receivable.id
    assert_not_includes receivable_ids, other_receivable.id
  end

  test "should require authentication when listing receivables" do
    get api_v1_receivables_url

    assert_response :unauthorized
  end

  test "should require read scope when listing receivables" do
    api_key_without_read = api_key_without_read_scope

    get api_v1_receivables_url, headers: api_headers(api_key_without_read)

    assert_response :forbidden
    json_response = JSON.parse(response.body)
    assert_equal "insufficient_scope", json_response["error"]
  ensure
    api_key_without_read&.destroy
  end

  test "should show receivable" do
    get api_v1_receivable_url(@receivable), headers: api_headers(@api_key)
    assert_response :success

    receivable = JSON.parse(response.body)["data"]
    assert_equal @receivable.id, receivable["id"]
    assert_equal "500.0", receivable["total_amount"]
    assert_equal 15, receivable["due_day"]
  end

  test "should require authentication when showing a receivable" do
    get api_v1_receivable_url(@receivable)

    assert_response :unauthorized
  end

  test "should require read scope when showing a receivable" do
    api_key_without_read = api_key_without_read_scope

    get api_v1_receivable_url(@receivable), headers: api_headers(api_key_without_read)

    assert_response :forbidden
    json_response = JSON.parse(response.body)
    assert_equal "insufficient_scope", json_response["error"]
  ensure
    api_key_without_read&.destroy
  end

  test "should not show another family's receivable" do
    other_family = Family.create!(name: "Other Family", currency: "USD", locale: "en")
    other_receivable = Receivable.create!(total_amount: 1000)
    other_family.accounts.create!(
      name: "Other Receivable",
      balance: 1000,
      currency: "USD",
      accountable: other_receivable
    )

    get api_v1_receivable_url(other_receivable), headers: api_headers(@api_key)
    assert_response :not_found
    json_response = JSON.parse(response.body)
    assert_equal "not_found", json_response["error"]
  end

  private

    def api_key_without_read_scope
      ApiKey.new(
        user: @user,
        name: "No Read Key",
        scopes: [],
        display_key: "test_no_read_#{SecureRandom.hex(8)}",
        source: "mobile"
      ).tap { |api_key| api_key.save!(validate: false) }
    end

    def api_headers(api_key)
      { "X-Api-Key" => api_key.plain_key }
    end
end
