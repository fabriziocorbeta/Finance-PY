# frozen_string_literal: true

require "test_helper"

class Api::V1::GoalsControllerTest < ActionDispatch::IntegrationTest
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

    # Goal valida must_have_at_least_one_linked_account: sin un goal_account
    # asociado, create! falla con :at_least_one_linked_account_required.
    @goal = @family.goals.new(
      name: "New Car",
      target_amount: 10000,
      currency: "USD",
      state: "active"
    )
    @goal.goal_accounts.build(account: accounts(:depository))
    @goal.save!
  end

  test "should list goals" do
    get api_v1_goals_url, headers: api_headers(@api_key)
    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response["data"].any? { |goal| goal["id"] == @goal.id }
    assert_equal @family.goals.count, json_response["meta"]["total_count"]
  end

  test "should not list another family's goals" do
    other_family = Family.create!(name: "Other Family", currency: "USD", locale: "en")
    # Goal exige >=1 cuenta vinculada (must_have_at_least_one_linked_account),
    # asi que la familia ajena tambien necesita una cuenta propia.
    other_account = other_family.accounts.create!(
      name: "Other Checking",
      balance: 0,
      currency: "USD",
      accountable: Depository.new
    )
    other_goal = other_family.goals.new(
      name: "Other Car",
      target_amount: 15000,
      currency: "USD"
    )
    other_goal.goal_accounts.build(account: other_account)
    other_goal.save!

    get api_v1_goals_url, headers: api_headers(@api_key)
    assert_response :success

    goal_ids = JSON.parse(response.body)["data"].map { |g| g["id"] }
    assert_includes goal_ids, @goal.id
    assert_not_includes goal_ids, other_goal.id
  end

  test "should require authentication when listing goals" do
    get api_v1_goals_url

    assert_response :unauthorized
  end

  test "should require read scope when listing goals" do
    api_key_without_read = api_key_without_read_scope

    get api_v1_goals_url, headers: api_headers(api_key_without_read)

    assert_response :forbidden
    json_response = JSON.parse(response.body)
    assert_equal "insufficient_scope", json_response["error"]
  ensure
    api_key_without_read&.destroy
  end

  test "should show goal" do
    get api_v1_goal_url(@goal), headers: api_headers(@api_key)
    assert_response :success

    goal = JSON.parse(response.body)["data"]
    assert_equal @goal.id, goal["id"]
    assert_equal @goal.name, goal["name"]
    assert_equal @goal.state, goal["state"]
  end

  test "should require authentication when showing a goal" do
    get api_v1_goal_url(@goal)

    assert_response :unauthorized
  end

  test "should require read scope when showing a goal" do
    api_key_without_read = api_key_without_read_scope

    get api_v1_goal_url(@goal), headers: api_headers(api_key_without_read)

    assert_response :forbidden
    json_response = JSON.parse(response.body)
    assert_equal "insufficient_scope", json_response["error"]
  ensure
    api_key_without_read&.destroy
  end

  test "should not show another family's goal" do
    other_family = Family.create!(name: "Other Family", currency: "USD", locale: "en")
    # Goal exige >=1 cuenta vinculada (must_have_at_least_one_linked_account),
    # asi que la familia ajena tambien necesita una cuenta propia.
    other_account = other_family.accounts.create!(
      name: "Other Checking",
      balance: 0,
      currency: "USD",
      accountable: Depository.new
    )
    other_goal = other_family.goals.new(
      name: "Other Car",
      target_amount: 15000,
      currency: "USD"
    )
    other_goal.goal_accounts.build(account: other_account)
    other_goal.save!

    get api_v1_goal_url(other_goal), headers: api_headers(@api_key)
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
