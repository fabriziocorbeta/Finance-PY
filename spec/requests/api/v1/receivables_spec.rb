# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'API V1 Receivables', type: :request do
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
      scopes: [],
      display_key: key,
      source: 'mobile'
    ).tap { |api_key| api_key.save!(validate: false) }
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

  let!(:receivable) do
    rec = Receivable.create!(total_amount: 500, installment_count: 5, due_day: 15)
    family.accounts.create!(
      name: 'Client Receivable',
      balance: 500,
      currency: 'USD',
      owner: user,
      accountable: rec
    )
    rec
  end

  path '/api/v1/receivables' do
    get 'List receivables' do
      tags 'Receivables'
      security [ { apiKeyAuth: [] } ]
      produces 'application/json'
      parameter name: :page, in: :query, type: :integer, required: false,
                description: 'Page number (default: 1)'
      parameter name: :per_page, in: :query, type: :integer, required: false,
                description: 'Items per page (default: 25, max: 100)'

      response '200', 'receivables listed' do
        schema '$ref' => '#/components/schemas/ReceivableCollection'

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

    post 'Create a receivable' do
      tags 'Receivables'
      security [ { apiKeyAuth: [] } ]
      consumes 'application/json'
      produces 'application/json'
      parameter name: :body, in: :body, required: true, schema: {
        type: :object,
        properties: {
          name: { type: :string, description: 'Account name for receivable' },
          total_amount: { type: :number, description: 'Total receivable amount' },
          balance: { type: :number, description: 'Initial account balance' },
          installment_count: { type: :integer, description: 'Number of installments' },
          due_day: { type: :integer, description: 'Day of month payment is due (1-31)' },
          currency: { type: :string, description: 'Currency code' },
          notes: { type: :string, description: 'Notes' }
        }
      }

      response '201', 'receivable created' do
        schema '$ref' => '#/components/schemas/ReceivableResponse'

        let(:body) do
          {
            name: 'New Receivable Account',
            total_amount: 1200,
            balance: 1200,
            installment_count: 6,
            due_day: 10,
            currency: 'USD'
          }
        end

        run_test!
      end

      response '401', 'unauthorized' do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:'X-Api-Key') { nil }
        let(:body) do
          {
            name: 'New Receivable Account',
            total_amount: 1200
          }
        end

        run_test!
      end

      response '403', 'forbidden - requires write scope' do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:'X-Api-Key') { api_key_without_write_scope.plain_key }
        let(:body) do
          {
            name: 'New Receivable Account',
            total_amount: 1200
          }
        end

        run_test!
      end

      response '422', 'unprocessable entity' do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:body) do
          {
            name: 'Invalid Receivable',
            total_amount: 100,
            due_day: 35
          }
        end

        run_test!
      end
    end
  end

  path '/api/v1/receivables/{id}' do
    parameter name: :id, in: :path, type: :string, required: true, description: 'Receivable ID',
              schema: { type: :string, format: :uuid }

    get 'Retrieve a receivable' do
      tags 'Receivables'
      security [ { apiKeyAuth: [] } ]
      produces 'application/json'

      let(:id) { receivable.id }

      response '200', 'receivable retrieved' do
        schema '$ref' => '#/components/schemas/ReceivableResponse'

        run_test!
      end

      response '401', 'unauthorized' do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:id) { receivable.id }
        let(:'X-Api-Key') { nil }

        run_test!
      end

      response '403', 'forbidden - requires read scope' do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:id) { receivable.id }
        let(:'X-Api-Key') { api_key_without_read_scope.plain_key }

        run_test!
      end

      response '404', 'receivable not found' do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:id) { SecureRandom.uuid }

        run_test!
      end
    end

    patch 'Update a receivable' do
      tags 'Receivables'
      security [ { apiKeyAuth: [] } ]
      consumes 'application/json'
      produces 'application/json'

      parameter name: :body, in: :body, required: true, schema: {
        type: :object,
        properties: {
          name: { type: :string },
          total_amount: { type: :number },
          balance: { type: :number },
          installment_count: { type: :integer },
          due_day: { type: :integer },
          currency: { type: :string },
          notes: { type: :string }
        }
      }

      response '200', 'receivable updated' do
        schema '$ref' => '#/components/schemas/ReceivableResponse'

        let(:id) { receivable.id }
        let(:body) do
          {
            name: 'Updated Receivable Name',
            total_amount: 750,
            due_day: 20
          }
        end

        run_test!
      end

      response '401', 'unauthorized' do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:id) { receivable.id }
        let(:'X-Api-Key') { nil }
        let(:body) do
          {
            total_amount: 750
          }
        end

        run_test!
      end

      response '403', 'forbidden - requires write scope' do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:id) { receivable.id }
        let(:'X-Api-Key') { api_key_without_write_scope.plain_key }
        let(:body) do
          {
            total_amount: 750
          }
        end

        run_test!
      end

      response '404', 'receivable not found' do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:id) { SecureRandom.uuid }
        let(:body) do
          {
            total_amount: 750
          }
        end

        run_test!
      end

      response '422', 'unprocessable entity' do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:id) { receivable.id }
        let(:body) do
          {
            due_day: 35
          }
        end

        run_test!
      end
    end

    delete 'Delete a receivable' do
      tags 'Receivables'
      security [ { apiKeyAuth: [] } ]
      produces 'application/json'

      response '200', 'receivable deleted' do
        schema '$ref' => '#/components/schemas/DeleteResponse'

        let(:id) { receivable.id }

        run_test!
      end

      response '401', 'unauthorized' do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:id) { receivable.id }
        let(:'X-Api-Key') { nil }

        run_test!
      end

      response '403', 'forbidden - requires write scope' do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:id) { receivable.id }
        let(:'X-Api-Key') { api_key_without_write_scope.plain_key }

        run_test!
      end

      response '404', 'receivable not found' do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        let(:id) { SecureRandom.uuid }

        run_test!
      end
    end
  end
end
