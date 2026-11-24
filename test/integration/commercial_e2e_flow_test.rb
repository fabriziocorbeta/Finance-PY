# frozen_string_literal: true

require "test_helper"

# End-to-end commercial journey test covering the critical path:
# Signup -> Login -> Create PYG wallet -> Record income & expense ->
# Create product & complete sale -> Recalculate monthly budget ->
# Query dashboard summary (native widget data source) ->
# Reports summary & CSV export -> Family full ZIP export ->
# Strict cross-tenant RLS isolation against a second newly registered family.
#
# NOTE: Dedicated endpoints `GET /api/v1/widget_summary` and persistent in-app
# notifications do not yet exist in config/routes.rb (widgets currently read the
# cached `/api/v1/dashboard` payload, and web notifications use transient flash
# streams via `Notifiable`). Once those endpoints are added, extend this suite.
class CommercialE2EFlowTest < ActionDispatch::IntegrationTest
  setup do
    InviteCode.destroy_all
    @previous_onboarding_state = Setting.onboarding_state
    Setting.onboarding_state = "open"

    @shared_app = Doorkeeper::Application.find_or_create_by!(name: "FinancePY Mobile") do |app|
      app.redirect_uri = "financespy://oauth/callback"
      app.scopes = "read read_write"
      app.confidential = false
    end
    @shared_app.update!(scopes: "read read_write")
    MobileDevice.instance_variable_set(:@shared_oauth_application, nil)

    @device_info = {
      device_id: "e2e-android-#{SecureRandom.hex(6)}",
      device_name: "Galaxy S24",
      device_type: "android",
      os_version: "15",
      app_version: "0.2.0"
    }
  end

  teardown do
    Setting.onboarding_state = @previous_onboarding_state if defined?(@previous_onboarding_state)
  end

  test "full commercial lifecycle with PYG precision and strict multi-tenant isolation" do
    email = "commercial_e2e_#{SecureRandom.hex(4)}@example.com"
    password = "SecurePass123!"

    # 1. Signup
    post "/api/v1/auth/signup", params: {
      user: {
        email: email,
        password: password,
        first_name: "Ana",
        last_name: "Comercial"
      },
      device: @device_info
    }
    assert_response :created
    signup_body = JSON.parse(response.body)
    assert signup_body["access_token"].present?
    user_id = signup_body.dig("user", "id")
    assert user_id.present?

    user = User.auth_find_by_id(user_id)
    family = RlsContext.with_family(user.family_id) do
      Family.find(user.family_id).tap { |f| f.update!(currency: "PYG", locale: "es", business_mode_enabled: true) }
    end

    # 2. Login
    post "/api/v1/auth/login", params: {
      email: email,
      password: password,
      device: @device_info
    }
    assert_response :ok
    login_body = JSON.parse(response.body)
    token = login_body["access_token"]
    assert token.present?
    auth_headers = { "Authorization" => "Bearer #{token}" }

    # 3. Create PYG wallet (Depository account)
    post api_v1_accounts_url,
         params: {
           account: {
             accountable_type: "Depository",
             name: "Billetera Guaraníes",
             balance: 1_000_000,
             currency: "PYG"
           }
         },
         headers: auth_headers
    assert_response :created
    account_body = JSON.parse(response.body)
    account_id = account_body["id"]
    assert account_id.present?
    assert_equal "PYG", account_body["currency"]

    # 4. Record income & expense transactions in PYG
    today = Date.current
    post api_v1_transactions_url,
         params: {
           transaction: {
             account_id: account_id,
             date: today.to_s,
             amount: "500000",
             nature: "income",
             name: "Cobro Honorarios",
             currency: "PYG"
           }
         },
         headers: auth_headers
    assert_response :created
    income_body = JSON.parse(response.body)
    assert_equal "income", income_body["classification"]
    assert_equal 500_000, income_body["signed_amount_cents"]

    user = RlsContext.with_auth_bypass { User.find_by!(email: email) }
    expense_category_id = RlsContext.with_family(user.family_id) do
      user.family.categories.create!(name: "Supermercado", color: "#10b981", lucide_icon: "shopping-cart").id
    end

    post api_v1_transactions_url,
         params: {
           transaction: {
             account_id: account_id,
             category_id: expense_category_id,
             date: today.to_s,
             amount: "150000",
             nature: "expense",
             name: "Superseis",
             currency: "PYG"
           }
         },
         headers: auth_headers
    assert_response :created
    expense_body = JSON.parse(response.body)
    expense_id = expense_body["id"]
    assert_equal "expense", expense_body["classification"]
    assert_equal(-150_000, expense_body["signed_amount_cents"])

    # 5. Create product, create draft sale, and complete sale (stock decrement + entry creation)
    post api_v1_products_url,
         params: {
           product: {
             name: "Yerba Mate 1kg",
             sku: "YM-#{SecureRandom.hex(3)}",
             buy_price: 15_000,
             sell_price: 25_000,
             currency: "pyg",
             initial_stock: 10,
             min_stock: 2
           }
         },
         headers: auth_headers
    assert_response :created
    product_body = JSON.parse(response.body)["data"]
    product_id = product_body["id"]
    assert_equal 10, product_body["stock"]

    post api_v1_sales_url,
         params: {
           sale: {
             client_name: "Cliente Comercial SA",
             currency: "pyg",
             account_id: account_id,
             sale_items_attributes: [
               { product_id: product_id, quantity: 2, unit_price: 25_000 }
             ]
           }
         },
         headers: auth_headers
    assert_response :created
    sale_id = JSON.parse(response.body).dig("data", "id")
    assert sale_id.present?

    post complete_api_v1_sale_url(sale_id), headers: auth_headers
    assert_response :ok
    completed_sale = JSON.parse(response.body)["data"]
    assert_equal "completed", completed_sale["status"]
    assert_equal 50_000.0, completed_sale["total"]

    get api_v1_product_url(product_id), headers: auth_headers
    assert_response :ok
    assert_equal 8, JSON.parse(response.body).dig("data", "stock")

    # 6. Create & query current month budget (recalculated spending includes recorded expense)
    post api_v1_budgets_url,
         params: {
           budget: {
             start_date: today.beginning_of_month.to_s,
             end_date: today.end_of_month.to_s,
             budgeted_spending: 1_000_000,
             expected_income: 1_500_000
           }
         },
         headers: auth_headers
    assert_response :created
    budget_id = JSON.parse(response.body).dig("data", "id")

    get api_v1_budget_url(budget_id), headers: auth_headers
    assert_response :ok
    budget_data = JSON.parse(response.body)["data"]
    assert_equal 150_000.0, budget_data["actual_spending"]
    assert_equal 1_000_000.0, budget_data["budgeted_spending"]

    # 7. Query dashboard summary (native Android/iOS widget data source)
    get api_v1_dashboard_url, headers: auth_headers
    assert_response :ok
    dashboard_body = JSON.parse(response.body)
    assert_equal "PYG", dashboard_body["currency"]
    assert_equal 150_000.0, dashboard_body.dig("outflows_donut", "total")

    # 8. Export data: Reports CSV + full FamilyExport job
    get api_v1_reports_summary_url, headers: auth_headers
    assert_response :ok
    reports_body = JSON.parse(response.body)
    assert_equal 150_000.0, reports_body.dig("summary", "expense")

    get api_v1_reports_export_transactions_url, headers: auth_headers
    assert_response :ok
    assert_equal "text/csv", response.media_type
    assert_includes response.body, "Category"

    assert_enqueued_with(job: FamilyDataExportJob) do
      post api_v1_family_exports_url, headers: auth_headers
    end
    assert_response :accepted
    export_id = JSON.parse(response.body).dig("data", "id")
    assert export_id.present?

    # 9. Cross-tenant isolation: Tenant B cannot access any resource from Tenant A
    post "/api/v1/auth/signup", params: {
      user: {
        email: "tenant_b_#{SecureRandom.hex(4)}@example.com",
        password: password,
        first_name: "Carlos",
        last_name: "OtroTenant"
      },
      device: @device_info.merge(device_id: "e2e-tenant-b-#{SecureRandom.hex(6)}")
    }
    assert_response :created
    tenant_b_token = JSON.parse(response.body)["access_token"]
    tenant_b_user = User.auth_find_by_id(JSON.parse(response.body).dig("user", "id"))
    RlsContext.with_family(tenant_b_user.family_id) do
      Family.find(tenant_b_user.family_id).update!(business_mode_enabled: true)
    end
    tenant_b_headers = { "Authorization" => "Bearer #{tenant_b_token}" }

    get api_v1_account_url(account_id), headers: tenant_b_headers
    assert_response :not_found

    get api_v1_transaction_url(expense_id), headers: tenant_b_headers
    assert_response :not_found

    get api_v1_sale_url(sale_id), headers: tenant_b_headers
    assert_response :not_found

    get api_v1_budget_url(budget_id), headers: tenant_b_headers
    assert_response :not_found

    get api_v1_family_export_url(export_id), headers: tenant_b_headers
    assert_response :not_found

    get api_v1_dashboard_url, headers: tenant_b_headers
    assert_response :ok
    tenant_b_dashboard = JSON.parse(response.body)
    assert_equal 0.0, tenant_b_dashboard.dig("outflows_donut", "total")
    assert_not_equal family.id, tenant_b_user.family_id
  end
end
