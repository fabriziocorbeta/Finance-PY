require "test_helper"

class FragmentCachingTenantIsolationTest < ActionDispatch::IntegrationTest
  setup do
    @original_caching = ActionController::Base.perform_caching
    @original_store = Rails.cache
    ActionController::Base.perform_caching = true
    Rails.cache = ActiveSupport::Cache::MemoryStore.new

    # Family A setup
    @family_a = Family.create!(name: "Familia Alpha", currency: "USD")
    @user_a = User.create!(
      family: @family_a,
      email: "user_alpha_#{SecureRandom.hex(4)}@example.com",
      password: user_password_test,
      first_name: "UserAlpha",
      last_name: "Test"
    )
    @account_a = @family_a.accounts.create!(
      name: "Cuenta Alpha 123",
      balance: 1000,
      currency: "USD",
      accountable: Depository.new
    )
    @budget_a = Budget.find_or_bootstrap(@family_a, start_date: Date.current, user: @user_a)
    if (bc_a = @budget_a.budget_categories.first)
      bc_a.category.update!(name: "Categoria Alpha 123")
    end

    # Family B setup
    @family_b = Family.create!(name: "Familia Beta", currency: "USD")
    @user_b = User.create!(
      family: @family_b,
      email: "user_beta_#{SecureRandom.hex(4)}@example.com",
      password: user_password_test,
      first_name: "UserBeta",
      last_name: "Test"
    )
    @account_b = @family_b.accounts.create!(
      name: "Cuenta Beta 999",
      balance: 2000,
      currency: "USD",
      accountable: Depository.new
    )
    @budget_b = Budget.find_or_bootstrap(@family_b, start_date: Date.current, user: @user_b)
    if (bc_b = @budget_b.budget_categories.first)
      bc_b.category.update!(name: "Categoria Beta 999")
    end
  end

  teardown do
    ActionController::Base.perform_caching = @original_caching
    Rails.cache = @original_store
  end

  test "fragment caching prevents cross-tenant data leaks between families" do
    # 1. Login as User A and visit Family A budget page (Cache miss for A)
    sign_in @user_a
    get budget_path(month_year: @budget_a.to_param)
    assert_response :success

    body_a_first = @response.body
    assert_includes body_a_first, "Cuenta Alpha 123"
    assert_includes body_a_first, "Categoria Alpha 123"
    refute_includes body_a_first, "Cuenta Beta 999"
    refute_includes body_a_first, "Categoria Beta 999"

    # 2. Login as User B and visit Family B budget page (Cache miss for B)
    sign_in @user_b
    get budget_path(month_year: @budget_b.to_param)
    assert_response :success

    body_b_first = @response.body
    assert_includes body_b_first, "Cuenta Beta 999"
    assert_includes body_b_first, "Categoria Beta 999"
    refute_includes body_b_first, "Cuenta Alpha 123"
    refute_includes body_b_first, "Categoria Alpha 123"

    # 3. Re-visit as User A (Cache hit for A)
    sign_in @user_a
    get budget_path(month_year: @budget_a.to_param)
    assert_response :success

    body_a_second = @response.body
    assert_includes body_a_second, "Cuenta Alpha 123"
    assert_includes body_a_second, "Categoria Alpha 123"
    refute_includes body_a_second, "Cuenta Beta 999"
    refute_includes body_a_second, "Categoria Beta 999"

    # 4. Re-visit as User B (Cache hit for B)
    sign_in @user_b
    get budget_path(month_year: @budget_b.to_param)
    assert_response :success

    body_b_second = @response.body
    assert_includes body_b_second, "Cuenta Beta 999"
    assert_includes body_b_second, "Categoria Beta 999"
    refute_includes body_b_second, "Cuenta Alpha 123"
    refute_includes body_b_second, "Categoria Alpha 123"
  end
end
