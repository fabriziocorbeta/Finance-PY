# frozen_string_literal: true

require "test_helper"

class Api::V1::AccountSharingAccessTest < ActionDispatch::IntegrationTest
  setup do
    @family = families(:dylan_family)
    @admin = users(:family_admin)
    @restricted = users(:family_member)
    # family_member has access to depository and credit_card, but NOT investment
    @inaccessible_account = accounts(:investment)
    @accessible_account = accounts(:depository)

    @admin_token = create_token_for(@admin)
    @restricted_token = create_token_for(@restricted)
  end

  test "restricted user cannot create trade on inaccessible account" do
    post api_v1_trades_url,
      params: {
        trade: {
          account_id: @inaccessible_account.id,
          date: Date.current.to_s,
          type: "buy",
          ticker: "AAPL",
          qty: 1,
          price: 150
        }
      },
      headers: { "Authorization" => "Bearer #{@restricted_token.token}" }

    assert_response :not_found
  end

  test "restricted user cannot create valuation on inaccessible account" do
    post api_v1_valuations_url,
      params: {
        valuation: {
          account_id: @inaccessible_account.id,
          amount: 1000,
          date: Date.current.to_s
        }
      },
      headers: { "Authorization" => "Bearer #{@restricted_token.token}" }

    assert_response :not_found
  end

  test "restricted user cannot transfer from inaccessible account" do
    post api_v1_transfers_url,
      params: {
        transfer: {
          from_account_id: @inaccessible_account.id,
          to_account_id: @accessible_account.id,
          amount: 50,
          date: Date.current.to_s
        }
      },
      headers: { "Authorization" => "Bearer #{@restricted_token.token}" }

    assert_response :not_found
  end

  test "balance sheet for restricted user scopes to accessible accounts" do
    get api_v1_balance_sheet_url,
      headers: { "Authorization" => "Bearer #{@restricted_token.token}" }

    assert_response :success
  end

  private

    def create_token_for(user)
      app = Doorkeeper::Application.create!(name: "Test", redirect_uri: "urn:ietf:wg:oauth:2.0:oob", scopes: "read write read_write")
      Doorkeeper::AccessToken.create!(
        application: app,
        resource_owner_id: user.id,
        scopes: "read_write write"
      )
    end
end
