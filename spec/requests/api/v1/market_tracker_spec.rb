# frozen_string_literal: true

require "swagger_helper"

RSpec.describe "API V1 Market Tracker", type: :request do
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
      email: "api-market@example.com",
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

  path "/api/v1/market_tracker" do
    get "Get market indices, watchlist quotes, and featured chart" do
      tags "Market Tracker"
      produces "application/json"
      security [ api_key: [] ]

      parameter name: :ticker, in: :query, type: :string, required: false
      parameter name: :range, in: :query, type: :string, required: false
      parameter name: :refresh, in: :query, type: :string, required: false

      response "200", "market tracker retrieved" do
        run_test!
      end

      response "401", "unauthorized" do
        let(:"X-Api-Key") { "invalid_key" }
        run_test!
      end
    end
  end

  path "/api/v1/market_tracker/quote" do
    get "Get quote and historical series for a ticker" do
      tags "Market Tracker"
      produces "application/json"
      security [ api_key: [] ]

      parameter name: :ticker, in: :query, type: :string, required: true
      parameter name: :range, in: :query, type: :string, required: false

      response "200", "quote retrieved" do
        let(:ticker) { "^GSPC" }
        run_test!
      end

      response "401", "unauthorized" do
        let(:"X-Api-Key") { "invalid_key" }
        let(:ticker) { "^GSPC" }
        run_test!
      end
    end
  end
end
