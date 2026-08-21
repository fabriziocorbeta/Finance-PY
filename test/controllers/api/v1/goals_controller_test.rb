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

    @write_api_key = ApiKey.create!(
      user: @user,
      name: "Test Write Key",
      scopes: [ "read_write" ],
      source: "web",
      display_key: "test_write_#{SecureRandom.hex(8)}"
    )

    Redis.new.del("api_rate_limit:#{@api_key.id}")
    Redis.new.del("api_rate_limit:#{@write_api_key.id}")

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

  test "should create goal with account_ids" do
    account = accounts(:depository)
    params = {
      goal: {
        name: "Vacation Fund",
        target_amount: 5000,
        currency: "USD",
        account_ids: [ account.id ]
      }
    }

    assert_difference -> { @family.goals.count }, 1 do
      post api_v1_goals_url, params: params, headers: api_headers(@write_api_key), as: :json
    end

    assert_response :created
    json_response = JSON.parse(response.body)["data"]
    assert_equal "Vacation Fund", json_response["name"]

    created_goal = Goal.find(json_response["id"])
    assert_includes created_goal.linked_accounts, account
  end

  test "should create goal with goal_accounts_attributes" do
    account = accounts(:depository)
    params = {
      goal: {
        name: "House Fund",
        target_amount: 50000,
        currency: "USD",
        goal_accounts_attributes: [
          { account_id: account.id, allocated_amount: 1000 }
        ]
      }
    }

    assert_difference -> { @family.goals.count }, 1 do
      post api_v1_goals_url, params: params, headers: api_headers(@write_api_key), as: :json
    end

    assert_response :created
    json_response = JSON.parse(response.body)["data"]
    assert_equal "House Fund", json_response["name"]
  end

  test "should fail to create goal without linked accounts" do
    params = {
      goal: {
        name: "Unlinked Goal",
        target_amount: 2000,
        currency: "USD"
      }
    }

    assert_no_difference -> { @family.goals.count } do
      post api_v1_goals_url, params: params, headers: api_headers(@write_api_key), as: :json
    end

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_equal "validation_failed", json_response["error"]
  end

  test "should require write scope to create a goal" do
    params = {
      goal: {
        name: "Forbidden Goal",
        target_amount: 1000,
        currency: "USD",
        account_ids: [ accounts(:depository).id ]
      }
    }

    post api_v1_goals_url, params: params, headers: api_headers(@api_key), as: :json
    assert_response :forbidden
  end

  test "should update goal" do
    params = {
      goal: {
        name: "Updated Goal Name"
      }
    }

    patch api_v1_goal_url(@goal), params: params, headers: api_headers(@write_api_key), as: :json
    assert_response :success

    @goal.reload
    assert_equal "Updated Goal Name", @goal.name
  end

  test "should fail to update goal when removing all linked accounts" do
    params = {
      goal: {
        account_ids: []
      }
    }

    patch api_v1_goal_url(@goal), params: params, headers: api_headers(@write_api_key), as: :json
    assert_response :unprocessable_entity

    json_response = JSON.parse(response.body)
    assert_equal "validation_failed", json_response["error"]
  end

  test "should require write scope to update a goal" do
    params = {
      goal: {
        name: "Unauthorized Update"
      }
    }

    patch api_v1_goal_url(@goal), params: params, headers: api_headers(@api_key), as: :json
    assert_response :forbidden
  end

  test "should not update another family's goal" do
    other_family = Family.create!(name: "Other Family", currency: "USD", locale: "en")
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

    patch api_v1_goal_url(other_goal), params: { goal: { name: "Hacked" } }, headers: api_headers(@write_api_key), as: :json
    assert_response :not_found
  end

  test "should fail to destroy goal if not archived" do
    delete api_v1_goal_url(@goal), headers: api_headers(@write_api_key)
    assert_response :unprocessable_entity

    json_response = JSON.parse(response.body)
    assert_equal "validation_failed", json_response["error"]
    assert Goal.exists?(@goal.id)
  end

  test "should destroy goal if archived" do
    @goal.archive!

    assert_difference -> { @family.goals.count }, -1 do
      delete api_v1_goal_url(@goal), headers: api_headers(@write_api_key)
    end

    assert_response :no_content
    assert_not Goal.exists?(@goal.id)
  end

  test "should require write scope to destroy a goal" do
    @goal.archive!

    delete api_v1_goal_url(@goal), headers: api_headers(@api_key)
    assert_response :forbidden
  end

  test "should not destroy another family's goal" do
    other_family = Family.create!(name: "Other Family", currency: "USD", locale: "en")
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
    other_goal.archive!

    delete api_v1_goal_url(other_goal), headers: api_headers(@write_api_key)
    assert_response :not_found
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
