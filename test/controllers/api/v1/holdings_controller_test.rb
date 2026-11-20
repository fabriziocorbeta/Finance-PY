# frozen_string_literal: true

require "test_helper"

class Api::V1::HoldingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:family_admin)
    @user.api_keys.active.destroy_all

    @api_key = ApiKey.create!(
      user: @user,
      name: "Test Read Key",
      scopes: [ "read" ],
      source: "web",
      display_key: "test_read_#{SecureRandom.hex(8)}"
    )

    @holding = holdings(:one)

    other_account = families(:empty).accounts.create!(
      name: "Other Investment Account",
      accountable: Investment.new,
      balance: 1000,
      currency: "USD"
    )
    @other_holding = other_account.holdings.create!(
      security: securities(:aapl),
      date: Date.current,
      qty: 1,
      price: 100,
      amount: 100,
      currency: "USD"
    )
  end

  test "lists holdings accessible to the current family" do
    get api_v1_holdings_url, headers: api_headers(@api_key)

    assert_response :success
    response_data = JSON.parse(response.body)
    holding_ids = response_data["holdings"].map { |holding| holding["id"] }

    assert_includes holding_ids, @holding.id
    assert_not_includes holding_ids, @other_holding.id
    assert response_data.key?("pagination")
  end

  test "shows a holding with amount_cents/price_cents matching the formatted values" do
    get api_v1_holding_url(@holding), headers: api_headers(@api_key)

    assert_response :success
    response_data = JSON.parse(response.body)

    assert_equal @holding.id, response_data["id"]
    assert_equal 215_00, response_data["price_cents"]
    assert_equal 2150_00, response_data["amount_cents"]
    assert_equal @holding.account.id, response_data["account"]["id"]
    assert_equal @holding.security.ticker, response_data["security"]["ticker"]
  end

  test "returns not found for another family's holding" do
    get api_v1_holding_url(@other_holding), headers: api_headers(@api_key)

    assert_response :not_found
  end

  test "requires authentication" do
    get api_v1_holdings_url

    assert_response :unauthorized
  end

  test "requires read scope" do
    api_key_without_read = ApiKey.new(
      user: @user,
      name: "No Read Key",
      scopes: [],
      source: "web",
      display_key: "no_read_#{SecureRandom.hex(8)}"
    )
    api_key_without_read.save!(validate: false)

    get api_v1_holdings_url, headers: api_headers(api_key_without_read)

    assert_response :forbidden
  ensure
    api_key_without_read&.destroy
  end

  private

    def api_headers(api_key)
      { "X-Api-Key" => api_key.plain_key }
    end
end
