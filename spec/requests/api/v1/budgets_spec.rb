# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'API V1 Budgets', type: :request do
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

  let(:read_only_api_key) do
    key = ApiKey.generate_secure_key
    ApiKey.create!(
      user: user,
      name: 'Read Only Docs Key',
      key: key,
      scopes: %w[read],
      source: 'mobile'
    )
  end

  let(:api_key_without_read_scope) do
    key = ApiKey.generate_secure_key
    ApiKey.new(
      user: user,
      name: 'No Read Docs Key',
      key: key,
      scopes: [],
      display_key: key,
      source: 'mobile'
    ).tap { |k| k.save!(validate: false) }
  end

  let(:'X-Api-Key') { api_key.plain_key }

  let!(:budget) do
    family.budgets.create!(
      start_date: Date.new(2026, 1, 1),
      end_date: Date.new(2026, 1, 31),
      currency: 'USD',
      budgeted_spending: 2000,
      expected_income: 3000
    )
  end

  path '/api/v1/budgets' do
    get 'List budgets' do
      tags 'Budgets'
      security [ { apiKeyAuth: [] } ]
      produces 'application/json'
      parameter name: :page, in: :query, type: :integer, required: false,
                description: 'Page number (default: 1)'
      parameter name: :per_page, in: :query, type: :integer, required: false,
                description: 'Items per page (default: 25, max: 100)'

      response '200', 'budgets listed' do
        schema '$ref' => '#/components/schemas/BudgetCollection'

        run_test!
      end

      response '401', 'unauthorized' do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:'X-Api-Key') { nil }

        run_test!
      end

      response '403', 'forbidden - requires read scope' do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:'X-Api-Key') { api_key_without_read_scope.plain_key }

        run_test!
      end
    end

    post 'Create a budget' do
      tags 'Budgets'
      security [ { apiKeyAuth: [] } ]
      consumes 'application/json'
      produces 'application/json'
      parameter name: :body, in: :body, required: true, schema: {
        type: :object,
        properties: {
          budget: {
            type: :object,
            properties: {
              start_date: { type: :string, format: :date },
              end_date: { type: :string, format: :date, nullable: true },
              currency: { type: :string, nullable: true },
              budgeted_spending: { type: :number, nullable: true },
              expected_income: { type: :number, nullable: true }
            },
            required: %w[start_date]
          }
        },
        required: %w[budget]
      }

      let(:body) do
        {
          budget: {
            start_date: '2026-02-01',
            end_date: '2026-02-28',
            currency: 'USD',
            budgeted_spending: 1500.0,
            expected_income: 2500.0
          }
        }
      end

      response '201', 'budget created' do
        schema '$ref' => '#/components/schemas/BudgetResponse'

        run_test!
      end

      response '401', 'unauthorized' do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:'X-Api-Key') { nil }

        run_test!
      end

      response '403', 'forbidden - requires write scope' do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:'X-Api-Key') { read_only_api_key.plain_key }

        run_test!
      end

      response '422', 'validation error - duplicate dates' do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:body) do
          {
            budget: {
              start_date: '2026-01-01',
              end_date: '2026-01-31'
            }
          }
        end

        run_test!
      end
    end
  end

  path '/api/v1/budgets/{id}' do
    parameter name: :id, in: :path, type: :string, required: true, description: 'Budget ID'

    get 'Retrieve a budget' do
      tags 'Budgets'
      security [ { apiKeyAuth: [] } ]
      produces 'application/json'

      let(:id) { budget.id }

      response '200', 'budget retrieved' do
        schema '$ref' => '#/components/schemas/BudgetResponse'

        run_test!
      end

      response '401', 'unauthorized' do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:'X-Api-Key') { nil }

        run_test!
      end

      response '403', 'forbidden - requires read scope' do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:'X-Api-Key') { api_key_without_read_scope.plain_key }

        run_test!
      end

      response '404', 'budget not found' do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:id) { SecureRandom.uuid }

        run_test!
      end
    end

    patch 'Update a budget' do
      tags 'Budgets'
      security [ { apiKeyAuth: [] } ]
      consumes 'application/json'
      produces 'application/json'

      let(:id) { budget.id }

      parameter name: :body, in: :body, required: true, schema: {
        type: :object,
        properties: {
          budget: {
            type: :object,
            properties: {
              budgeted_spending: { type: :number, nullable: true },
              expected_income: { type: :number, nullable: true },
              currency: { type: :string, nullable: true }
            }
          }
        }
      }

      let(:body) do
        {
          budget: {
            budgeted_spending: 3000.0,
            expected_income: 4000.0
          }
        }
      end

      response '200', 'budget updated' do
        schema '$ref' => '#/components/schemas/BudgetResponse'

        run_test!
      end

      response '401', 'unauthorized' do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:'X-Api-Key') { nil }

        run_test!
      end

      response '403', 'forbidden - requires write scope' do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:'X-Api-Key') { read_only_api_key.plain_key }

        run_test!
      end

      response '404', 'budget not found' do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:id) { SecureRandom.uuid }

        run_test!
      end

      response '422', 'validation error' do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:body) do
          {
            budget: {
              start_date: nil
            }
          }
        end

        run_test!
      end
    end

    delete 'Delete a budget' do
      tags 'Budgets'
      security [ { apiKeyAuth: [] } ]

      let(:id) { budget.id }

      response '204', 'budget deleted' do
        run_test!
      end

      response '401', 'unauthorized' do
        let(:'X-Api-Key') { nil }

        run_test!
      end

      response '403', 'forbidden - requires write scope' do
        let(:'X-Api-Key') { read_only_api_key.plain_key }

        run_test!
      end

      response '404', 'budget not found' do
        let(:id) { SecureRandom.uuid }

        run_test!
      end
    end
  end
end
