# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'API V1 Goals', type: :request do
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

  let(:api_key_without_read_scope) do
    key = ApiKey.generate_secure_key
    ApiKey.new(
      user: user,
      name: 'No Read Docs Key',
      key: key,
      scopes: %w[write],
      display_key: key,
      source: 'mobile'
    ).tap { |k| k.save!(validate: false) }
  end

  let(:api_key_without_write_scope) do
    key = ApiKey.generate_secure_key
    ApiKey.create!(
      user: user,
      name: 'Read Only Docs Key',
      key: key,
      scopes: %w[read],
      source: 'web'
    )
  end

  let(:'X-Api-Key') { api_key.plain_key }

  let(:account) do
    Account.create!(
      family: family,
      name: 'Savings Account',
      balance: 5000.00,
      currency: 'USD',
      accountable: Depository.create!
    )
  end

  let!(:goal) do
    g = family.goals.new(
      name: 'Emergency Fund',
      target_amount: 10000.00,
      currency: 'USD',
      target_date: Date.new(2026, 12, 31),
      color: '#3b82f6',
      state: 'active'
    )
    g.goal_accounts.build(account: account, allocated_amount: 1000.00)
    g.save!
    g
  end

  let!(:archived_goal) do
    g = family.goals.new(
      name: 'Old Car Savings',
      target_amount: 5000.00,
      currency: 'USD',
      state: 'archived'
    )
    g.goal_accounts.build(account: account)
    g.save!
    g
  end

  path '/api/v1/goals' do
    get 'List goals' do
      tags 'Goals'
      security [ { apiKeyAuth: [] } ]
      produces 'application/json'
      parameter name: :page, in: :query, type: :integer, required: false,
                description: 'Page number (default: 1)'
      parameter name: :per_page, in: :query, type: :integer, required: false,
                description: 'Items per page (default: 25, max: 100)'

      response '200', 'goals listed' do
        schema '$ref' => '#/components/schemas/GoalCollection'

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

    post 'Create goal' do
      tags 'Goals'
      security [ { apiKeyAuth: [] } ]
      consumes 'application/json'
      produces 'application/json'
      parameter name: :body, in: :body, required: true, schema: {
        type: :object,
        properties: {
          goal: {
            type: :object,
            properties: {
              name: { type: :string, description: 'Goal name (required)' },
              target_amount: { type: :number, description: 'Target amount (required, > 0)' },
              currency: { type: :string, description: 'Currency code (optional, defaults to primary currency)' },
              target_date: { type: :string, format: :date, nullable: true },
              color: { type: :string, nullable: true },
              icon: { type: :string, nullable: true },
              notes: { type: :string, nullable: true },
              progress_basis: { type: :string, enum: %w[balance contributions], nullable: true },
              state: { type: :string, enum: %w[active paused completed archived], nullable: true },
              account_ids: {
                type: :array,
                items: { type: :string, format: :uuid },
                description: 'Array of account IDs to link to the goal (at least one linked account required)'
              },
              goal_accounts_attributes: {
                type: :array,
                items: {
                  type: :object,
                  properties: {
                    account_id: { type: :string, format: :uuid },
                    allocated_amount: { type: :number, nullable: true }
                  },
                  required: %w[account_id]
                },
                description: 'Goal accounts attributes for nested linking'
              }
            },
            required: %w[name target_amount]
          }
        },
        required: %w[goal]
      }

      let(:body) do
        {
          goal: {
            name: 'Vacation Fund',
            target_amount: 3000.00,
            currency: 'USD',
            target_date: '2026-08-01',
            account_ids: [ account.id ]
          }
        }
      end

      response '201', 'goal created with account_ids' do
        schema '$ref' => '#/components/schemas/GoalResponse'

        run_test!
      end

      response '201', 'goal created with goal_accounts_attributes' do
        schema '$ref' => '#/components/schemas/GoalResponse'

        let(:body) do
          {
            goal: {
              name: 'House Down Payment',
              target_amount: 50000.00,
              currency: 'USD',
              goal_accounts_attributes: [
                { account_id: account.id, allocated_amount: 5000.00 }
              ]
            }
          }
        end

        run_test!
      end

      response '400', 'bad request - goal parameter missing' do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:body) { {} }

        run_test!
      end

      response '401', 'unauthorized' do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:'X-Api-Key') { nil }

        run_test!
      end

      response '403', 'forbidden - requires write scope' do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:'X-Api-Key') { api_key_without_write_scope.plain_key }

        run_test!
      end

      response '422', 'validation error - missing linked accounts' do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:body) do
          {
            goal: {
              name: 'Unlinked Goal',
              target_amount: 2000.00,
              currency: 'USD'
            }
          }
        end

        run_test!
      end
    end
  end

  path '/api/v1/goals/{id}' do
    parameter name: :id, in: :path, type: :string, required: true, description: 'Goal ID'

    get 'Retrieve a goal' do
      tags 'Goals'
      security [ { apiKeyAuth: [] } ]
      produces 'application/json'

      let(:id) { goal.id }

      response '200', 'goal retrieved' do
        schema '$ref' => '#/components/schemas/GoalResponse'

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

      response '404', 'goal not found' do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:id) { SecureRandom.uuid }

        run_test!
      end
    end

    patch 'Update a goal' do
      tags 'Goals'
      security [ { apiKeyAuth: [] } ]
      consumes 'application/json'
      produces 'application/json'

      let(:id) { goal.id }

      parameter name: :body, in: :body, required: true, schema: {
        type: :object,
        properties: {
          goal: {
            type: :object,
            properties: {
              name: { type: :string },
              target_amount: { type: :number },
              target_date: { type: :string, format: :date, nullable: true },
              color: { type: :string, nullable: true },
              icon: { type: :string, nullable: true },
              notes: { type: :string, nullable: true },
              progress_basis: { type: :string, enum: %w[balance contributions] },
              state: { type: :string, enum: %w[active paused completed archived] },
              account_ids: {
                type: :array,
                items: { type: :string, format: :uuid }
              }
            }
          }
        }
      }

      let(:body) do
        {
          goal: {
            name: 'Updated Emergency Fund',
            target_amount: 15000.00
          }
        }
      end

      response '200', 'goal updated' do
        schema '$ref' => '#/components/schemas/GoalResponse'

        run_test!
      end

      response '400', 'bad request - goal parameter missing' do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:body) { {} }

        run_test!
      end

      response '401', 'unauthorized' do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:'X-Api-Key') { nil }

        run_test!
      end

      response '403', 'forbidden - requires write scope' do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:'X-Api-Key') { api_key_without_write_scope.plain_key }

        run_test!
      end

      response '404', 'goal not found' do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:id) { SecureRandom.uuid }

        run_test!
      end

      response '422', 'validation error - removing all linked accounts' do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:body) do
          {
            goal: {
              account_ids: []
            }
          }
        end

        run_test!
      end
    end

    delete 'Delete a goal' do
      tags 'Goals'
      security [ { apiKeyAuth: [] } ]

      let(:id) { archived_goal.id }

      response '204', 'goal deleted' do
        run_test!
      end

      response '401', 'unauthorized' do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:'X-Api-Key') { nil }

        run_test!
      end

      response '403', 'forbidden - requires write scope' do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:'X-Api-Key') { api_key_without_write_scope.plain_key }

        run_test!
      end

      response '404', 'goal not found' do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:id) { SecureRandom.uuid }

        run_test!
      end

      response '422', 'validation error - goal must be archived before deletion' do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:id) { goal.id }

        run_test!
      end
    end
  end
end
