# frozen_string_literal: true

require "test_helper"

class Api::V1::AndroidPurchasesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:family_admin)
    @family = @user.family
    @account = @family.accounts.first

    @user.api_keys.active.destroy_all

    @api_key = ApiKey.create!(
      user: @user,
      name: "Android Purchase Test Key",
      scopes: [ "read_write" ],
      display_key: "test_ap_#{SecureRandom.hex(8)}"
    )

    @read_only_api_key = ApiKey.create!(
      user: @user,
      name: "Android Purchase Read Only Key",
      scopes: [ "read" ],
      display_key: "test_apro_#{SecureRandom.hex(8)}",
      source: "mobile"
    )
  end

  test "creates android purchase with valid parameters and write scope API key" do
    params = {
      account_id: @account.id,
      amount: 150000,
      merchant: "FERIA ASUNCION S.A.",
      item: "Tarjeta GNB ••1234",
      timestamp: Time.current.iso8601,
      raw_text: "Compra por Gs. 150.000 en FERIA ASUNCION S.A."
    }

    assert_difference("@account.entries.count", 1) do
      post api_v1_android_purchases_url, params: params, headers: api_headers(@api_key)
    end

    assert_response :ok
    response_data = JSON.parse(response.body)
    assert_equal true, response_data["received"]
    assert_equal false, response_data["duplicate"]

    entry = @account.entries.order(created_at: :desc).first
    assert_equal "FERIA ASUNCION S.A. - Tarjeta GNB ••1234", entry.name
    assert_equal 150000.0, entry.amount.to_f
  end

  test "rejects purchase post with read-only API key" do
    params = {
      account_id: @account.id,
      amount: 150000,
      merchant: "FERIA ASUNCION S.A."
    }

    post api_v1_android_purchases_url, params: params, headers: api_headers(@read_only_api_key)
    assert_response :forbidden
  end

  test "rejects purchase post without authentication" do
    post api_v1_android_purchases_url, params: { account_id: @account.id, amount: 100 }
    assert_response :unauthorized
  end

  test "rejects purchase for account belonging to another family with generic error message" do
    other_family = families(:inactive_trial)
    other_account = Account.create!(
      family: other_family,
      name: "Other Account",
      balance: 0,
      currency: "USD",
      accountable: Depository.new
    )

    params = {
      account_id: other_account.id,
      amount: 50000,
      merchant: "Test Merchant"
    }

    post api_v1_android_purchases_url, params: params, headers: api_headers(@api_key)

    assert_response :unprocessable_entity
    response_data = JSON.parse(response.body)
    assert_equal "Unknown account_id: #{other_account.id}", response_data["error"]
  end

  private

    def api_headers(api_key)
      { "X-Api-Key" => api_key.display_key }
    end
end
