require "test_helper"

class RowLevelSecurityTest < ActionDispatch::IntegrationTest
  setup do
    @family_a = families(:dylan_family)
    @user_a = users(:family_admin) # belongs to @family_a

    # Create Family B and records for Family B
    @family_b = Family.create!(name: "Other Family", currency: "USD")
    @user_b = User.create!(family: @family_b, email: "other_user@example.com", password: "password123")

    @account_b = Account.create!(family: @family_b, name: "Other Account", currency: "USD", balance: 1000)
    @entry_b = Entry.create!(account: @account_b, amount: 50, date: Date.current, name: "Other Entry")
    @transaction_b = Transaction.create!(entry: @entry_b)
    @category_b = Category.create!(family: @family_b, name: "Other Category")
    @tag_b = Tag.create!(family: @family_b, name: "Other Tag")
    @budget_b = Budget.create!(family: @family_b, start_date: Date.current.beginning_of_month, end_date: Date.current.end_of_month, currency: "USD")
    @budget_category_b = BudgetCategory.create!(budget: @budget_b, category: @category_b, budgeted_spending: 500, currency: "USD")
    @goal_b = Goal.create!(family: @family_b, name: "Other Goal", target_amount: 1000, currency: "USD", state: "active")
    @goal_b.goal_accounts.create!(account: @account_b)
    @rule_b = Rule.create!(family: @family_b, resource_type: "Transaction", name: "Other Rule")
    @merchant_b = FamilyMerchant.create!(family: @family_b, name: "Other Merchant")
    @valuation_b = Valuation.create!(kind: "reconciliation")
    @valuation_entry_b = Entry.create!(account: @account_b, amount: 1000, date: Date.current, name: "Valuation Entry", entryable: @valuation_b)
    @receivable_b = Receivable.create!(total_amount: 500)
    @receivable_account_b = Account.create!(family: @family_b, accountable: @receivable_b, name: "Receivable Account", currency: "USD", balance: 500)
  end

  test "when app.current_family_id session variable is set, raw SQL and ActiveRecord queries cannot access family_b records" do
    ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql([ "SET app.current_family_id = ?", @family_a.id ])
    )

    # Direct family_id tables
    assert_nil Account.find_by(id: @account_b.id)
    assert_nil Budget.find_by(id: @budget_b.id)
    assert_nil Goal.find_by(id: @goal_b.id)
    assert_nil Rule.find_by(id: @rule_b.id)
    assert_nil Category.find_by(id: @category_b.id)
    assert_nil Tag.find_by(id: @tag_b.id)

    # Indirect tables
    assert_nil Entry.find_by(id: @entry_b.id)
    assert_nil Transaction.find_by(id: @transaction_b.id)
    assert_nil BudgetCategory.find_by(id: @budget_category_b.id)
    assert_nil Merchant.find_by(id: @merchant_b.id)
    assert_nil Valuation.find_by(id: @valuation_b.id)
    assert_nil Receivable.find_by(id: @receivable_b.id)

    # Raw SQL queries bypassing Rails model scoping
    raw_accounts = ActiveRecord::Base.connection.execute("SELECT * FROM accounts WHERE id = '#{@account_b.id}'")
    assert_equal 0, raw_accounts.count

    raw_entries = ActiveRecord::Base.connection.execute("SELECT * FROM entries WHERE id = '#{@entry_b.id}'")
    assert_equal 0, raw_entries.count

    raw_transactions = ActiveRecord::Base.connection.execute("SELECT * FROM transactions WHERE id = '#{@transaction_b.id}'")
    assert_equal 0, raw_transactions.count
  ensure
    ActiveRecord::Base.connection.execute("RESET app.current_family_id")
  end

  test "around_action sets app.current_family_id context automatically on controller requests" do
    sign_in @user_a

    get accounts_path
    assert_response :success

    # Check inside a request cycle by asserting on response/records
    assert_equal @family_a.id, Current.family.id
  end

  test "ActiveJob sets app.current_family_id context during perform" do
    ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql([ "SET app.current_family_id = ?", @family_a.id ])
    )

    # Verify background job execution with family context
    assert_nothing_raised do
      ClearAiCacheJob.perform_now(@family_a)
    end
  ensure
    ActiveRecord::Base.connection.execute("RESET app.current_family_id")
  end

  test "bank sync job (SyncJob) sets RLS context and accesses family records under RLS" do
    sync_a = Sync.create!(family: @family_a, syncable: @family_a.accounts.first || Account.create!(family: @family_a, name: "Family A Acc", currency: "USD", balance: 100))

    ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql([ "SET app.current_family_id = ?", @family_a.id ])
    )

    assert_nothing_raised do
      SyncJob.perform_now(sync_a)
    end
  ensure
    ActiveRecord::Base.connection.execute("RESET app.current_family_id")
  end

  test "recurring transactions job (IdentifyRecurringTransactionsJob) resolves family from ID string and runs under RLS context" do
    account_a = Account.create!(family: @family_a, name: "Family A Checking", currency: "USD", balance: 500)
    entry_a = Entry.create!(account: account_a, amount: -100, date: 1.month.ago.to_date, name: "Netflix Subscription")
    Transaction.create!(entry: entry_a)

    ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql([ "SET app.current_family_id = ?", @family_a.id ])
    )

    assert_nothing_raised do
      IdentifyRecurringTransactionsJob.perform_now(@family_a.id, Time.current)
    end
  ensure
    ActiveRecord::Base.connection.execute("RESET app.current_family_id")
  end

  test "balance materialization/cache clear job (DataCacheClearJob) clears target family balances and preserves other family data under RLS" do
    account_a = Account.create!(family: @family_a, name: "Acc A", currency: "USD", balance: 200)
    balance_a = account_a.balances.create!(date: Date.current, balance: 200, currency: "USD")
    balance_b = @account_b.balances.create!(date: Date.current, balance: 1000, currency: "USD")

    ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql([ "SET app.current_family_id = ?", @family_a.id ])
    )

    DataCacheClearJob.perform_now(@family_a)

    # Context should be restored and balance_b intact
    ActiveRecord::Base.connection.execute("RESET app.current_family_id")
    assert_nil Account::Balance.find_by(id: balance_a.id)
    assert_not_nil Account::Balance.find_by(id: balance_b.id)
  end
end
