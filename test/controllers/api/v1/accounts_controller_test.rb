# frozen_string_literal: true

require "test_helper"

class Api::V1::AccountsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:family_admin) # dylan_family user
    @other_family_user = users(:family_member)
    @other_family_user.update!(family: families(:empty))

    @user.api_keys.active.destroy_all
    @api_key = ApiKey.create!(
      user: @user,
      name: "Test Read Key",
      scopes: [ "read" ],
      source: "web",
      display_key: "test_read_#{SecureRandom.hex(8)}"
    )

    @other_family_user.api_keys.active.destroy_all
    @other_family_api_key = ApiKey.create!(
      user: @other_family_user,
      name: "Other Family Read Key",
      scopes: [ "read" ],
      source: "web",
      display_key: "other_family_read_#{SecureRandom.hex(8)}"
    )

    @write_api_key = ApiKey.create!(
      user: @user,
      name: "Test Write Key",
      scopes: [ "read_write" ],
      source: "mobile",
      display_key: "test_write_#{SecureRandom.hex(8)}"
    )
    Redis.new.del("api_rate_limit:#{@write_api_key.id}")
  end

  test "should require authentication" do
    get "/api/v1/accounts"
    assert_response :unauthorized

    response_body = JSON.parse(response.body)
    assert_equal "unauthorized", response_body["error"]
  end

  test "should require read_accounts scope" do
    api_key_without_read = ApiKey.new(
      user: @user,
      name: "No Read Key",
      scopes: [],
      source: "web",
      display_key: "no_read_#{SecureRandom.hex(8)}"
    )
    # Valid persisted API keys can only be read/read_write; this intentionally
    # bypasses validations to exercise the runtime insufficient-scope guard.
    api_key_without_read.save!(validate: false)

    get "/api/v1/accounts", params: {}, headers: api_headers(api_key_without_read)

    assert_response :forbidden
    response_body = JSON.parse(response.body)
    assert_equal "insufficient_scope", response_body["error"]
  ensure
    api_key_without_read&.destroy
  end

  test "should return user's family accounts successfully" do
    get "/api/v1/accounts", params: {}, headers: api_headers(@api_key)

    assert_response :success
    response_body = JSON.parse(response.body)

    # Should have accounts array
    assert response_body.key?("accounts")
    assert response_body["accounts"].is_a?(Array)

    # Should have pagination metadata
    assert response_body.key?("pagination")
    assert response_body["pagination"].key?("page")
    assert response_body["pagination"].key?("per_page")
    assert response_body["pagination"].key?("total_count")
    assert response_body["pagination"].key?("total_pages")

    # All accounts should belong to user's family
    response_body["accounts"].each do |account|
      # We'll validate this by checking the user's family has these accounts
      family_account_names = @user.family.accounts.pluck(:name)
      assert_includes family_account_names, account["name"]
    end
  end

  test "should only return active accounts" do
    # Make one account inactive
    inactive_account = accounts(:depository)
    inactive_account.disable!

    get "/api/v1/accounts", params: {}, headers: api_headers(@api_key)

    assert_response :success
    response_body = JSON.parse(response.body)

    # Should not include the inactive account
    account_names = response_body["accounts"].map { |a| a["name"] }
    assert_not_includes account_names, inactive_account.name
  end

  test "should include disabled accounts when requested" do
    inactive_account = accounts(:depository)
    inactive_account.disable!

    get "/api/v1/accounts", params: { include_disabled: true }, headers: api_headers(@api_key)

    assert_response :success
    response_body = JSON.parse(response.body)

    account = response_body["accounts"].find { |account_data| account_data["id"] == inactive_account.id }
    assert_not_nil account
    assert_equal "disabled", account["status"]
  end

  test "should show active account" do
    account = accounts(:depository)

    get "/api/v1/accounts/#{account.id}", headers: api_headers(@api_key)

    assert_response :success
    response_body = JSON.parse(response.body)
    assert_equal account.id, response_body["id"]
    assert_equal account.status, response_body["status"]
    assert_equal account.balance_money.format, response_body["balance"]
    assert_equal money_cents(account.balance_money), response_body["balance_cents"]
    assert_equal account.cash_balance_money.format, response_body["cash_balance"]
    assert_equal money_cents(account.cash_balance_money), response_body["cash_balance_cents"]
    assert_nullable_equal account.subtype, response_body["subtype"]
    assert response_body.key?("institution_name")
    assert response_body.key?("institution_domain")
    assert_nullable_equal account.institution_name, response_body["institution_name"]
    assert_nullable_equal account.institution_domain, response_body["institution_domain"]
    assert_equal account.created_at.iso8601, response_body["created_at"]
    assert_equal account.updated_at.iso8601, response_body["updated_at"]
  end

  test "should return 404 for unknown account on show" do
    get "/api/v1/accounts/#{SecureRandom.uuid}", headers: api_headers(@api_key)

    assert_response :not_found
    response_body = JSON.parse(response.body)
    assert_equal "not_found", response_body["error"]
  end

  test "should return 404 for malformed account id on show" do
    get "/api/v1/accounts/not-a-uuid", headers: api_headers(@api_key)

    assert_response :not_found
    response_body = JSON.parse(response.body)
    assert_equal "not_found", response_body["error"]
    assert_equal "Account not found", response_body["message"]
  end

  test "should require authentication on show" do
    account = accounts(:depository)

    get "/api/v1/accounts/#{account.id}"

    assert_response :unauthorized
    response_body = JSON.parse(response.body)
    assert_equal "unauthorized", response_body["error"]
  end

  test "should require read scope on show" do
    account = accounts(:depository)
    api_key_without_read = ApiKey.new(
      user: @user,
      name: "No Read Show Key",
      scopes: [],
      source: "web",
      display_key: "no_read_show_#{SecureRandom.hex(8)}"
    )
    # Valid persisted API keys can only be read/read_write; this intentionally
    # bypasses validations to exercise the runtime insufficient-scope guard.
    api_key_without_read.save!(validate: false)

    get "/api/v1/accounts/#{account.id}", headers: api_headers(api_key_without_read)

    assert_response :forbidden
    response_body = JSON.parse(response.body)
    assert_equal "insufficient_scope", response_body["error"]
  ensure
    api_key_without_read&.destroy
  end

  test "should hide disabled account by default on show" do
    inactive_account = accounts(:depository)
    inactive_account.disable!

    get "/api/v1/accounts/#{inactive_account.id}", headers: api_headers(@api_key)

    assert_response :not_found
  end

  test "should show disabled account when requested" do
    inactive_account = accounts(:depository)
    inactive_account.disable!

    get "/api/v1/accounts/#{inactive_account.id}",
        params: { include_disabled: true },
        headers: api_headers(@api_key)

    assert_response :success
    response_body = JSON.parse(response.body)
    assert_equal inactive_account.id, response_body["id"]
    assert_equal "disabled", response_body["status"]
  end

  test "should expose subtype across account types" do
    expected_subtypes = {
      accounts(:depository) => "checking",
      accounts(:credit_card) => "credit_card",
      accounts(:investment) => "brokerage",
      accounts(:loan) => "mortgage",
      accounts(:property) => "single_family_home",
      accounts(:vehicle) => "sedan",
      accounts(:crypto) => "exchange",
      accounts(:other_asset) => "collectible",
      accounts(:other_liability) => "personal_debt"
    }

    expected_subtypes.each { |account, subtype| account.accountable.update!(subtype: subtype) }

    expected_subtypes.each do |account, subtype|
      get "/api/v1/accounts/#{account.id}", headers: api_headers(@api_key)

      assert_response :success
      assert_equal subtype, JSON.parse(response.body)["subtype"]
    end
  end

  test "should not return other family's accounts" do
    get "/api/v1/accounts", params: {}, headers: api_headers(@other_family_api_key)

    assert_response :success
    response_body = JSON.parse(response.body)

    # Should return empty array since other family has no accounts in fixtures
    assert_equal [], response_body["accounts"]
    assert_equal 0, response_body["pagination"]["total_count"]
  end

  test "should handle pagination parameters" do
    # Test with pagination params
    get "/api/v1/accounts", params: { page: 1, per_page: 2 }, headers: api_headers(@api_key)

    assert_response :success
    response_body = JSON.parse(response.body)

    # Should respect per_page limit
    assert response_body["accounts"].length <= 2
    assert_equal 1, response_body["pagination"]["page"]
    assert_equal 2, response_body["pagination"]["per_page"]
  end

  test "should return proper account data structure" do
    get "/api/v1/accounts", params: {}, headers: api_headers(@api_key)

    assert_response :success
    response_body = JSON.parse(response.body)

    # Should have at least one account from fixtures
    assert response_body["accounts"].length > 0

    account = response_body["accounts"].first

    # Check required fields are present
    required_fields = %w[id name balance balance_cents cash_balance cash_balance_cents currency classification account_type]
    required_fields.each do |field|
      assert account.key?(field), "Account should have #{field} field"
    end

    # Check data types
    assert account["id"].is_a?(String), "ID should be string (UUID)"
    assert account["name"].is_a?(String), "Name should be string"
    assert account["balance"].is_a?(String), "Balance should be string (money)"
    assert account["balance_cents"].is_a?(Integer), "Balance cents should be integer"
    assert account["cash_balance_cents"].is_a?(Integer), "Cash balance cents should be integer"
    assert account["currency"].is_a?(String), "Currency should be string"
    assert %w[asset liability].include?(account["classification"]), "Classification should be asset or liability"
  end

  test "should handle invalid pagination parameters gracefully" do
    # Test with invalid page number
    get "/api/v1/accounts", params: { page: -1, per_page: "invalid" }, headers: api_headers(@api_key)

    # Should still return success with default pagination
    assert_response :success
    response_body = JSON.parse(response.body)

    # Should have pagination info (with defaults applied)
    assert response_body.key?("pagination")
    assert response_body["pagination"]["page"] >= 1
    assert response_body["pagination"]["per_page"] > 0
  end

  test "should sort accounts alphabetically" do
    get "/api/v1/accounts", params: {}, headers: api_headers(@api_key)

    assert_response :success
    response_body = JSON.parse(response.body)

    # Should be sorted alphabetically by name
    account_names = response_body["accounts"].map { |a| a["name"] }
    assert_equal account_names.sort, account_names
  end

  test "should return balance series for account" do
    account = accounts(:depository)

    get "/api/v1/accounts/#{account.id}/balance_series", headers: api_headers(@api_key)

    assert_response :success
    response_body = JSON.parse(response.body)

    assert_equal account.currency, response_body["currency"]
    assert_equal "last_30_days", response_body["period"]
    assert response_body["series"].is_a?(Array)
    assert response_body["series"].length > 0

    point = response_body["series"].first
    assert point.key?("date")
    assert point.key?("balance")
    assert point["balance"].is_a?(Numeric)

    if response_body["trend"]
      trend = response_body["trend"]
      assert trend.key?("start_balance")
      assert trend.key?("end_balance")
      assert trend.key?("value")
      assert trend.key?("direction")
    end
  end

  test "should respect custom period for balance series" do
    account = accounts(:depository)

    get "/api/v1/accounts/#{account.id}/balance_series", params: { period: "last_90_days" }, headers: api_headers(@api_key)

    assert_response :success
    response_body = JSON.parse(response.body)
    assert_equal "last_90_days", response_body["period"]
  end

  test "should return 404 for missing or unauthorized account on balance_series" do
    get "/api/v1/accounts/#{SecureRandom.uuid}/balance_series", headers: api_headers(@api_key)
    assert_response :not_found

    account = accounts(:depository)
    get "/api/v1/accounts/#{account.id}/balance_series", headers: api_headers(@other_family_api_key)
    assert_response :not_found
  end

  test "should create a Depository account" do
    assert_difference "Account.count", 1 do
      post "/api/v1/accounts",
           params: {
             account: {
               accountable_type: "Depository",
               name: "Cuenta corriente",
               balance: 500000,
               currency: "PYG"
             }
           },
           headers: api_headers(@write_api_key)
    end

    assert_response :created
    json_response = JSON.parse(response.body)
    assert_equal "Cuenta corriente", json_response["name"]

    account = Account.order(:created_at).last
    assert_instance_of Depository, account.accountable
    assert_equal @user.family, account.family
    assert_equal @user, account.owner
  end

  test "should create a CreditCard account with type-specific attributes" do
    assert_difference "Account.count", 1 do
      post "/api/v1/accounts",
           params: {
             account: {
               accountable_type: "CreditCard",
               name: "Tarjeta Visa",
               balance: 100000,
               currency: "PYG",
               accountable_attributes: { available_credit: 900000, apr: 45.5 }
             }
           },
           headers: api_headers(@write_api_key)
    end

    assert_response :created
    account = Account.order(:created_at).last
    assert_instance_of CreditCard, account.accountable
    assert_equal 900000, account.accountable.available_credit.to_i
  end

  test "should reject unsupported accountable types" do
    assert_no_difference "Account.count" do
      post "/api/v1/accounts",
           params: { account: { accountable_type: "Property", name: "Casa" } },
           headers: api_headers(@write_api_key)
    end

    assert_response :unprocessable_entity
    assert_equal "unsupported_accountable_type", JSON.parse(response.body)["error"]
  end

  test "should reject account creation without write scope" do
    post "/api/v1/accounts",
         params: { account: { accountable_type: "Depository", name: "Cuenta" } },
         headers: api_headers(@api_key)

    assert_response :forbidden
  end

  test "should ignore accountable_attributes not permitted for the given type" do
    post "/api/v1/accounts",
         params: {
           account: {
             accountable_type: "Depository",
             name: "Cuenta con extras no permitidos",
             balance: 0,
             currency: "PYG",
             accountable_attributes: { apr: 99, available_credit: 12345 }
           }
         },
         headers: api_headers(@write_api_key)

    assert_response :created
    account = Account.order(:created_at).last
    assert_instance_of Depository, account.accountable
  end

  private

    def api_headers(api_key)
      { "X-Api-Key" => api_key.plain_key }
    end

    def money_cents(money)
      (money.amount * money.currency.minor_unit_conversion).round(0).to_i
    end

    def assert_nullable_equal(expected, actual)
      expected.nil? ? assert_nil(actual) : assert_equal(expected, actual)
    end
end
