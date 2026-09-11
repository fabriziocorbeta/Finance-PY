# frozen_string_literal: true

require "test_helper"

class Api::V1::GoalPledgesControllerTest < ActionDispatch::IntegrationTest
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
      source: "mobile",
      display_key: "test_write_#{SecureRandom.hex(8)}"
    )

    Redis.new.del("api_rate_limit:#{@api_key.id}")
    Redis.new.del("api_rate_limit:#{@write_api_key.id}")

    @account = accounts(:depository)
    @goal = @family.goals.new(
      name: "House Fund",
      target_amount: 50000,
      currency: "USD",
      state: "active"
    )
    @goal.goal_accounts.build(account: @account)
    @goal.save!

    @pledge = @goal.goal_pledges.create!(
      account: @account,
      amount: 100,
      currency: "USD"
    )
  end

  test "should list pledges for a goal" do
    get api_v1_goal_pledges_url(@goal), headers: api_headers(@api_key)
    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal 1, json_response["data"].length
    pledge_data = json_response["data"].first
    assert_equal @pledge.id, pledge_data["id"]
    assert_equal @goal.id, pledge_data["goal_id"]
    assert_equal @account.id, pledge_data["account_id"]
    assert_equal @account.name, pledge_data["account_name"]
    assert_equal 100.0, pledge_data["amount"].to_f
    assert_equal "USD", pledge_data["currency"]
    assert_equal "open", pledge_data["status"]
    assert pledge_data.key?("days_left")
  end

  test "should require authentication to list pledges" do
    get api_v1_goal_pledges_url(@goal)
    assert_response :unauthorized
  end

  test "should require read scope to list pledges" do
    no_read_key = api_key_without_read_scope
    get api_v1_goal_pledges_url(@goal), headers: api_headers(no_read_key)
    assert_response :forbidden
  ensure
    no_read_key&.destroy
  end

  test "should return 404 when listing pledges for another family's goal" do
    other_family = Family.create!(name: "Other Family", currency: "USD", locale: "en")
    other_account = other_family.accounts.create!(
      name: "Other Checking",
      balance: 0,
      currency: "USD",
      accountable: Depository.new
    )
    other_goal = other_family.goals.new(name: "Other Goal", target_amount: 1000, currency: "USD")
    other_goal.goal_accounts.build(account: other_account)
    other_goal.save!

    get api_v1_goal_pledges_url(other_goal), headers: api_headers(@api_key)
    assert_response :not_found
  end

  test "should create pledge with valid params" do
    params = {
      pledge: {
        amount: 250,
        account_id: @account.id
      }
    }

    assert_difference -> { @goal.goal_pledges.count }, 1 do
      post api_v1_goal_pledges_url(@goal), params: params, headers: api_headers(@write_api_key), as: :json
    end

    assert_response :created
    json_response = JSON.parse(response.body)["data"]
    assert_equal 250.0, json_response["amount"].to_f
    assert_equal @account.id, json_response["account_id"]
    assert_equal @account.name, json_response["account_name"]
    assert_equal "open", json_response["status"]
  end

  test "should fail to create pledge for unlinked account" do
    unlinked_account = @family.accounts.create!(
      name: "Unlinked Savings",
      balance: 500,
      currency: "USD",
      accountable: Depository.new
    )

    params = {
      pledge: {
        amount: 200,
        account_id: unlinked_account.id
      }
    }

    assert_no_difference -> { GoalPledge.count } do
      post api_v1_goal_pledges_url(@goal), params: params, headers: api_headers(@write_api_key), as: :json
    end

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_equal "validation_failed", json_response["error"]
  end

  test "should fail to create duplicate open pledge" do
    params = {
      pledge: {
        amount: 100, # Same amount and account as @pledge which is open
        account_id: @account.id
      }
    }

    assert_no_difference -> { GoalPledge.count } do
      post api_v1_goal_pledges_url(@goal), params: params, headers: api_headers(@write_api_key), as: :json
    end

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_equal "validation_failed", json_response["error"]
  end

  test "should require write scope to create pledge" do
    params = { pledge: { amount: 300, account_id: @account.id } }
    post api_v1_goal_pledges_url(@goal), params: params, headers: api_headers(@api_key), as: :json
    assert_response :forbidden
  end

  test "should cancel pledge on destroy" do
    delete api_v1_goal_pledge_url(@goal, @pledge), headers: api_headers(@write_api_key)
    assert_response :success

    @pledge.reload
    assert_equal "cancelled", @pledge.status

    json_response = JSON.parse(response.body)["data"]
    assert_equal "cancelled", json_response["status"]
  end

  test "should fail to cancel an already cancelled pledge" do
    @pledge.cancel!

    delete api_v1_goal_pledge_url(@goal, @pledge), headers: api_headers(@write_api_key)
    assert_response :unprocessable_entity

    json_response = JSON.parse(response.body)
    assert_equal "validation_failed", json_response["error"]
  end

  test "should renew open pledge" do
    original_expires_at = @pledge.expires_at

    patch renew_api_v1_goal_pledge_url(@goal, @pledge), headers: api_headers(@write_api_key)
    assert_response :success

    @pledge.reload
    assert_operator @pledge.expires_at, :>, original_expires_at
  end

  test "should fail to renew non-open pledge" do
    @pledge.cancel!

    patch renew_api_v1_goal_pledge_url(@goal, @pledge), headers: api_headers(@write_api_key)
    assert_response :unprocessable_entity

    json_response = JSON.parse(response.body)
    assert_equal "validation_failed", json_response["error"]
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
