# frozen_string_literal: true

require "swagger_helper"

RSpec.describe "API V1 Watchlist Items", type: :request do
  let(:family) do
    Family.create!(
      name: "API Family",
      currency: "USD",
      locale: "en",
      date_format: "%m-%d-%Y"
    )
  end

  let(:user) do
    family.users.create!(
      email: "api-watchlist@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
  end

  let(:api_key) do
    key = ApiKey.generate_secure_key
    ApiKey.create!(
      user: user,
      name: "API Docs Key",
      key: key,
      scopes: %w[read_write],
      source: "web"
    )
  end

  let(:"X-Api-Key") { api_key.plain_key }

  path "/api/v1/watchlist_items" do
    post "Add an ETF, stock, or index to the family watchlist" do
      tags "Watchlist"
      consumes "application/json"
      produces "application/json"
      security [ api_key: [] ]

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          ticker: { type: :string },
          exchange_operating_mic: { type: :string, nullable: true }
        },
        required: %w[ticker]
      }

      response "201", "watchlist item created" do
        let(:body) { { ticker: "VOO" } }
        run_test!
      end

      response "401", "unauthorized" do
        let(:"X-Api-Key") { "invalid_key" }
        let(:body) { { ticker: "VOO" } }
        run_test!
      end
    end
  end

  path "/api/v1/watchlist_items/{id}" do
    delete "Remove an item from the family watchlist" do
      tags "Watchlist"
      produces "application/json"
      security [ api_key: [] ]

      parameter name: :id, in: :path, type: :string, required: true

      response "200", "watchlist item deleted" do
        let(:security_record) { Security.create!(ticker: "VOO", name: "Vanguard S&P 500 ETF") }
        let(:id) { family.watchlist_items.create!(security: security_record, category: "etf").id }
        run_test!
      end

      response "401", "unauthorized" do
        let(:"X-Api-Key") { "invalid_key" }
        let(:id) { "00000000-0000-0000-0000-000000000000" }
        run_test!
      end
    end
  end
end
