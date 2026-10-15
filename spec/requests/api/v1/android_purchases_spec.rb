# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'API V1 Android Purchases', type: :request do
  let(:family) do
    Family.create!(
      name: 'API Family',
      currency: 'USD',
      locale: 'en',
      date_format: '%m-%d-%Y'
    )
  end

  let(:user) do
    family.users.create!(
      email: 'api-user@example.com',
      password: 'password123',
      password_confirmation: 'password123'
    )
  end

  let(:api_key) do
    key = ApiKey.generate_secure_key
    ApiKey.create!(
      user: user,
      name: 'API Docs Key',
      key: key,
      scopes: %w[read_write],
      source: 'web'
    )
  end

  let(:'X-Api-Key') { api_key.plain_key }

  let!(:account) do
    Account.create!(
      family: family,
      name: 'API Test Account',
      balance: 1000,
      currency: 'USD',
      accountable: Depository.new
    )
  end

  path '/api/v1/android_purchases' do
    post 'Create an Android purchase' do
      tags 'Android Purchases'
      security [ { apiKeyAuth: [] } ]
      consumes 'application/json'
      produces 'application/json'

      parameter name: :purchase, in: :body, schema: {
        type: :object,
        properties: {
          account_id: { type: :string, format: :uuid },
          amount: { type: :string, description: 'Amount (can be formatted with grouping separators)' },
          merchant: { type: :string },
          item: { type: :string },
          timestamp: { type: :string, format: :'date-time' },
          raw_text: { type: :string, nullable: true },
          nature: { type: :string, enum: ['income', 'expense'], nullable: true, description: 'Defaults to expense if omitted' }
        },
        required: %w[amount merchant]
      }

      response '200', 'purchase created' do
        schema type: :object,
               properties: {
                 received: { type: :boolean },
                 duplicate: { type: :boolean }
               }

        let(:purchase) do
          {
            account_id: account.id,
            amount: '150000',
            merchant: 'Test Merchant',
            item: 'Test Item',
            timestamp: Time.current.iso8601,
            nature: 'expense'
          }
        end
        run_test!
      end

      response '422', 'unprocessable entity' do
        schema type: :object,
               properties: {
                 error: { type: :string }
               }

        let(:purchase) do
          {
            account_id: account.id,
            amount: 'invalid',
            merchant: 'Test Merchant',
            item: 'Test Item',
            timestamp: Time.current.iso8601
          }
        end
        run_test!
      end

      response '401', 'unauthorized' do
        schema '$ref' => '#/components/schemas/ErrorResponse'
        let(:'X-Api-Key') { 'invalid_key' }
        let(:purchase) do
          {
            account_id: account.id,
            amount: '150000',
            merchant: 'Test Merchant',
            item: 'Test Item'
          }
        end
        run_test!
      end
    end
  end
end
