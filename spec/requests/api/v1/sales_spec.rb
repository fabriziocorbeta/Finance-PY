# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'API V1 Sales', type: :request do
  let(:family) do
    Family.create!(
      name: 'API Family',
      currency: 'PYG',
      locale: 'es',
      date_format: '%d/%m/%Y',
      business_mode_enabled: true
    )
  end

  let(:user) do
    family.users.create!(
      email: 'api-sales-user@example.com',
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

  let!(:account) do
    family.accounts.create!(
      name: 'Sales Account',
      balance: 0,
      currency: 'PYG',
      owner: user,
      accountable: Depository.new
    )
  end

  let!(:product) do
    family.products.create!(
      name: 'Sample Product',
      sku: 'PROD-01',
      buy_price: 1000,
      sell_price: 2000,
      currency: 'pyg',
      stock: 50,
      min_stock: 5
    )
  end

  let!(:sale) do
    family.sales.create!(
      account: account,
      client_name: 'Client A',
      currency: 'pyg',
      sale_items_attributes: [
        { product_id: product.id, quantity: 2, unit_price: 2000 }
      ]
    )
  end

  path '/api/v1/sales' do
    get 'List sales' do
      tags 'Sales'
      security [ { apiKeyAuth: [] } ]
      produces 'application/json'
      parameter name: :page, in: :query, type: :integer, required: false,
                description: 'Page number (default: 1)'
      parameter name: :per_page, in: :query, type: :integer, required: false,
                description: 'Items per page (default: 25, max: 100)'

      response '200', 'sales listed' do
        schema '$ref' => '#/components/schemas/SaleCollection'
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

    post 'Create a sale' do
      tags 'Sales'
      security [ { apiKeyAuth: [] } ]
      consumes 'application/json'
      produces 'application/json'
      parameter name: :body, in: :body, required: true, schema: {
        type: :object,
        properties: {
          sale: {
            type: :object,
            properties: {
              client_name: { type: :string },
              currency: { type: :string, enum: %w[pyg usd] },
              account_id: { type: :string, format: :uuid },
              payment_method: { type: :string, nullable: true },
              invoice_number: { type: :string, nullable: true },
              condition: { type: :string, nullable: true },
              notes: { type: :string, nullable: true },
              delivery_address: { type: :string, nullable: true },
              delivery_date: { type: :string, format: :date, nullable: true },
              carrier: { type: :string, nullable: true },
              sale_items_attributes: {
                type: :array,
                items: {
                  type: :object,
                  properties: {
                    product_id: { type: :string, format: :uuid },
                    quantity: { type: :integer },
                    unit_price: { type: :number }
                  }
                }
              }
            }
          }
        }
      }

      response '201', 'sale created' do
        schema '$ref' => '#/components/schemas/SaleResponse'
        let(:body) do
          {
            sale: {
              client_name: 'New Client',
              currency: 'pyg',
              account_id: account.id,
              sale_items_attributes: [
                { product_id: product.id, quantity: 1, unit_price: 2000 }
              ]
            }
          }
        end
        run_test!
      end

      response '401', 'unauthorized' do
        schema '$ref' => '#/components/schemas/ErrorResponse'
        let(:'X-Api-Key') { nil }
        let(:body) { { sale: { client_name: 'New Client', account_id: account.id } } }
        run_test!
      end

      response '403', 'forbidden - requires write scope' do
        schema '$ref' => '#/components/schemas/ErrorResponse'
        let(:'X-Api-Key') { api_key_without_write_scope.plain_key }
        let(:body) { { sale: { client_name: 'New Client', account_id: account.id } } }
        run_test!
      end

      response '422', 'unprocessable entity' do
        schema '$ref' => '#/components/schemas/ErrorResponse'
        let(:body) { { sale: { client_name: 'Missing Account' } } }
        run_test!
      end
    end
  end

  path '/api/v1/sales/{id}' do
    parameter name: :id, in: :path, type: :string, required: true, description: 'Sale ID',
              schema: { type: :string, format: :uuid }

    get 'Retrieve a sale' do
      tags 'Sales'
      security [ { apiKeyAuth: [] } ]
      produces 'application/json'

      let(:id) { sale.id }

      response '200', 'sale retrieved' do
        schema '$ref' => '#/components/schemas/SaleResponse'
        run_test!
      end

      response '401', 'unauthorized' do
        schema '$ref' => '#/components/schemas/ErrorResponse'
        let(:'X-Api-Key') { nil }
        run_test!
      end

      response '404', 'sale not found' do
        schema '$ref' => '#/components/schemas/ErrorResponse'
        let(:id) { SecureRandom.uuid }
        run_test!
      end
    end
  end

  path '/api/v1/sales/{id}/invoice_photo' do
    parameter name: :id, in: :path, type: :string, required: true, description: 'Sale ID',
              schema: { type: :string, format: :uuid }

    get 'Download or view sale invoice photo' do
      tags 'Sales'
      security [ { apiKeyAuth: [] } ]
      produces 'image/jpeg', 'image/png', 'application/pdf', 'application/json'
      parameter name: :disposition, in: :query, type: :string, required: false,
                description: 'Content-Disposition mode (inline or attachment)'

      let(:id) { sale.id }

      response '200', 'invoice photo streamed' do
        before do
          sale.invoice_photo.attach(
            io: StringIO.new('fake-jpeg-bytes'),
            filename: 'receipt.jpg',
            content_type: 'image/jpeg'
          )
        end

        run_test!
      end

      response '401', 'unauthorized' do
        schema '$ref' => '#/components/schemas/ErrorResponse'
        let(:'X-Api-Key') { nil }
        run_test!
      end

      response '404', 'invoice photo or sale not found' do
        schema '$ref' => '#/components/schemas/ErrorResponse'
        run_test!
      end
    end

    post 'Upload or replace sale invoice photo' do
      tags 'Sales'
      security [ { apiKeyAuth: [] } ]
      consumes 'multipart/form-data'
      produces 'application/json'
      parameter name: :invoice_photo, in: :formData, type: :file, required: true,
                description: 'Invoice photo file (JPEG, PNG, GIF, WebP or PDF up to 10MB)'

      let(:id) { sale.id }
      let(:invoice_photo) do
        Rack::Test::UploadedFile.new(
          Rails.root.join('test/fixtures/files/receipt.jpg'),
          'image/jpeg'
        )
      end

      response '200', 'invoice photo uploaded' do
        schema '$ref' => '#/components/schemas/SaleResponse'
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

      response '422', 'invalid or missing file' do
        schema '$ref' => '#/components/schemas/ErrorResponse'
        let(:invoice_photo) do
          Rack::Test::UploadedFile.new(
            Rails.root.join('test/fixtures/files/test.txt'),
            'text/plain'
          )
        end
        run_test!
      end
    end

    delete 'Delete sale invoice photo' do
      tags 'Sales'
      security [ { apiKeyAuth: [] } ]
      produces 'application/json'

      let(:id) { sale.id }

      response '200', 'invoice photo deleted' do
        schema '$ref' => '#/components/schemas/SaleResponse'
        before do
          sale.invoice_photo.attach(
            io: StringIO.new('fake-jpeg-bytes'),
            filename: 'receipt.jpg',
            content_type: 'image/jpeg'
          )
        end
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

      response '404', 'sale not found' do
        schema '$ref' => '#/components/schemas/ErrorResponse'
        let(:id) { SecureRandom.uuid }
        run_test!
      end
    end
  end
end
