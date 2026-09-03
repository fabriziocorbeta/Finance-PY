require "test_helper"

class RowLevelSecurityTest < ActionDispatch::IntegrationTest
  def self.ensure_non_superuser_role
    return if @non_superuser_role_ensured

    config = ActiveRecord::Base.connection_db_config.configuration_hash
    dbname = config[:database] || config[:dbname] || "sure_test"
    pg_conn = PG.connect(
      host: config[:host] || "127.0.0.1",
      port: config[:port] || 5432,
      dbname: dbname,
      user: config[:user] || config[:username],
      password: config[:password]
    )
    pg_conn.exec("SET lock_timeout = '5s';")
    pg_conn.exec("CREATE ROLE app_user WITH LOGIN NOSUPERUSER NOBYPASSRLS;") rescue nil
    pg_conn.exec("GRANT ALL ON ALL TABLES IN SCHEMA public TO app_user;")
    pg_conn.exec("GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO app_user;")
    pg_conn.exec("GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO app_user;")
    pg_conn.exec("GRANT ALL ON SCHEMA public TO app_user;")

    policy_count = pg_conn.exec("SELECT COUNT(*) FROM pg_policies WHERE policyname = 'products_family_isolation_policy';").getvalue(0, 0).to_i
    if policy_count == 0
      pg_conn.exec <<~SQL
        CREATE OR REPLACE FUNCTION current_family_id() RETURNS uuid AS $$
        BEGIN
          RETURN NULLIF(current_setting('app.current_family_id', true), '')::uuid;
        EXCEPTION
          WHEN invalid_text_representation THEN
            RETURN NULL;
        END;
        $$ LANGUAGE plpgsql STABLE;

        DO $$
        DECLARE
          tbl text;
          direct_tables text[] := ARRAY['accounts', 'budgets', 'goals', 'rules', 'categories', 'tags', 'fleet_vehicles', 'products', 'purchase_orders', 'sales', 'recurring_transactions'];
        BEGIN
          FOREACH tbl IN ARRAY direct_tables LOOP
            EXECUTE 'ALTER TABLE ' || tbl || ' ENABLE ROW LEVEL SECURITY;';
            EXECUTE 'ALTER TABLE ' || tbl || ' FORCE ROW LEVEL SECURITY;';
            EXECUTE 'DROP POLICY IF EXISTS ' || tbl || '_family_isolation_policy ON ' || tbl || ';';
            EXECUTE 'CREATE POLICY ' || tbl || '_family_isolation_policy ON ' || tbl ||
                    ' FOR ALL USING (family_id = current_family_id()) WITH CHECK (family_id = current_family_id());';
          END LOOP;
        END $$;

        ALTER TABLE merchants ENABLE ROW LEVEL SECURITY;
        ALTER TABLE merchants FORCE ROW LEVEL SECURITY;
        DROP POLICY IF EXISTS merchants_family_isolation_policy ON merchants;
        CREATE POLICY merchants_family_isolation_policy ON merchants FOR ALL USING (family_id = current_family_id() OR family_id IS NULL) WITH CHECK (family_id = current_family_id() OR family_id IS NULL);

        ALTER TABLE entries ENABLE ROW LEVEL SECURITY;
        ALTER TABLE entries FORCE ROW LEVEL SECURITY;
        DROP POLICY IF EXISTS entries_family_isolation_policy ON entries;
        CREATE POLICY entries_family_isolation_policy ON entries FOR ALL USING (account_id IN (SELECT id FROM accounts WHERE family_id = current_family_id())) WITH CHECK (account_id IN (SELECT id FROM accounts WHERE family_id = current_family_id()));

        ALTER TABLE budget_categories ENABLE ROW LEVEL SECURITY;
        ALTER TABLE budget_categories FORCE ROW LEVEL SECURITY;
        DROP POLICY IF EXISTS budget_categories_family_isolation_policy ON budget_categories;
        CREATE POLICY budget_categories_family_isolation_policy ON budget_categories FOR ALL USING (budget_id IN (SELECT id FROM budgets WHERE family_id = current_family_id())) WITH CHECK (budget_id IN (SELECT id FROM budgets WHERE family_id = current_family_id()));

    ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
        ALTER TABLE transactions FORCE ROW LEVEL SECURITY;
        DROP POLICY IF EXISTS transactions_family_isolation_policy ON transactions;
        CREATE POLICY transactions_family_isolation_policy ON transactions FOR ALL USING (family_id = current_family_id()) WITH CHECK (family_id = current_family_id());

        ALTER TABLE valuations ENABLE ROW LEVEL SECURITY;
        ALTER TABLE valuations FORCE ROW LEVEL SECURITY;
        DROP POLICY IF EXISTS valuations_family_isolation_policy ON valuations;
        CREATE POLICY valuations_family_isolation_policy ON valuations FOR ALL USING (family_id = current_family_id()) WITH CHECK (family_id = current_family_id());

        ALTER TABLE receivables ENABLE ROW LEVEL SECURITY;
        ALTER TABLE receivables FORCE ROW LEVEL SECURITY;
        DROP POLICY IF EXISTS receivables_family_isolation_policy ON receivables;
        CREATE POLICY receivables_family_isolation_policy ON receivables FOR ALL USING (family_id = current_family_id()) WITH CHECK (family_id = current_family_id());

        ALTER TABLE fuel_logs ENABLE ROW LEVEL SECURITY;
        ALTER TABLE fuel_logs FORCE ROW LEVEL SECURITY;
        DROP POLICY IF EXISTS fuel_logs_family_isolation_policy ON fuel_logs;
        CREATE POLICY fuel_logs_family_isolation_policy ON fuel_logs FOR ALL USING (fleet_vehicle_id IN (SELECT id FROM fleet_vehicles WHERE family_id = current_family_id())) WITH CHECK (fleet_vehicle_id IN (SELECT id FROM fleet_vehicles WHERE family_id = current_family_id()));

        ALTER TABLE fuel_log_lines ENABLE ROW LEVEL SECURITY;
        ALTER TABLE fuel_log_lines FORCE ROW LEVEL SECURITY;
        DROP POLICY IF EXISTS fuel_log_lines_family_isolation_policy ON fuel_log_lines;
        CREATE POLICY fuel_log_lines_family_isolation_policy ON fuel_log_lines FOR ALL USING (fuel_log_id IN (SELECT id FROM fuel_logs WHERE fleet_vehicle_id IN (SELECT id FROM fleet_vehicles WHERE family_id = current_family_id()))) WITH CHECK (fuel_log_id IN (SELECT id FROM fuel_logs WHERE fleet_vehicle_id IN (SELECT id FROM fleet_vehicles WHERE family_id = current_family_id())));

        ALTER TABLE purchase_order_items ENABLE ROW LEVEL SECURITY;
        ALTER TABLE purchase_order_items FORCE ROW LEVEL SECURITY;
        DROP POLICY IF EXISTS purchase_order_items_family_isolation_policy ON purchase_order_items;
        CREATE POLICY purchase_order_items_family_isolation_policy ON purchase_order_items FOR ALL USING (purchase_order_id IN (SELECT id FROM purchase_orders WHERE family_id = current_family_id())) WITH CHECK (purchase_order_id IN (SELECT id FROM purchase_orders WHERE family_id = current_family_id()));

        ALTER TABLE sale_items ENABLE ROW LEVEL SECURITY;
        ALTER TABLE sale_items FORCE ROW LEVEL SECURITY;
        DROP POLICY IF EXISTS sale_items_family_isolation_policy ON sale_items;
        CREATE POLICY sale_items_family_isolation_policy ON sale_items FOR ALL USING (sale_id IN (SELECT id FROM sales WHERE family_id = current_family_id())) WITH CHECK (sale_id IN (SELECT id FROM sales WHERE family_id = current_family_id()));

        ALTER TABLE product_stock_movements ENABLE ROW LEVEL SECURITY;
        ALTER TABLE product_stock_movements FORCE ROW LEVEL SECURITY;
        DROP POLICY IF EXISTS product_stock_movements_family_isolation_policy ON product_stock_movements;
        CREATE POLICY product_stock_movements_family_isolation_policy ON product_stock_movements FOR ALL USING (product_id IN (SELECT id FROM products WHERE family_id = current_family_id())) WITH CHECK (product_id IN (SELECT id FROM products WHERE family_id = current_family_id()));
      SQL
    end
    @non_superuser_role_ensured = true
  ensure
    pg_conn&.close
  end

  setup do
    self.class.ensure_non_superuser_role

    @family_a = families(:dylan_family)
    @user_a = users(:family_admin) # belongs to @family_a

    # Create Family B and records for Family B
    @family_b = Family.create!(name: "Other Family", currency: "USD")
    @user_b = User.create!(family: @family_b, email: "other_user@example.com", password: "password123")

    @account_b = Account.create!(family: @family_b, name: "Other Account", currency: "USD", balance: 1000, accountable: Depository.new)
    @entry_b = Entry.create!(account: @account_b, amount: 50, date: Date.current, name: "Other Entry", currency: @account_b.currency, entryable: Transaction.new)
    @transaction_b = @entry_b.entryable
    @category_b = Category.create!(family: @family_b, name: "Other Category")
    @tag_b = Tag.create!(family: @family_b, name: "Other Tag")
    @budget_b = Budget.create!(family: @family_b, start_date: Date.current.beginning_of_month, end_date: Date.current.end_of_month, currency: "USD")
    @budget_category_b = BudgetCategory.create!(budget: @budget_b, category: @category_b, budgeted_spending: 500, currency: "USD")
    @goal_b = Goal.new(family: @family_b, name: "Other Goal", target_amount: 1000, currency: "USD", state: "active")
    @goal_b.goal_accounts.build(account: @account_b)
    @goal_b.save!
    @rule_b = Rule.create!(family: @family_b, resource_type: "Transaction", name: "Other Rule", actions: [ Rule::Action.new(action_type: "exclude_transaction") ])
    @merchant_b = FamilyMerchant.create!(family: @family_b, name: "Other Merchant")
    @valuation_b = Valuation.create!(family: @family_b, kind: "reconciliation")
    @valuation_entry_b = Entry.create!(account: @account_b, amount: 1000, date: Date.current, name: "Valuation Entry", currency: @account_b.currency, entryable: @valuation_b)
    @receivable_b = Receivable.create!(family: @family_b, total_amount: 500)
    @receivable_account_b = Account.create!(family: @family_b, accountable: @receivable_b, name: "Receivable Account", currency: "USD", balance: 500)
    @fleet_vehicle_b = FleetVehicle.create!(family: @family_b, plate: "ABC-123", brand: "Toyota", model: "Corolla", year: 2020, status: "active")
    @fuel_log_b = FuelLog.create!(fleet_vehicle: @fleet_vehicle_b, account: @account_b, logged_at: Date.current, fuel_log_lines_attributes: [ { fuel_type: "nafta", liters: 40, cost: 300000 } ])

    # Business active tables (Family B)
    @product_b = Product.create!(family: @family_b, name: "Other Product", buy_price: 10000, sell_price: 15000, stock: 10)
    @purchase_order_b = PurchaseOrder.create!(family: @family_b, supplier_name: "Other Supplier")
    @purchase_order_item_b = PurchaseOrderItem.create!(purchase_order: @purchase_order_b, product: @product_b, quantity: 5, unit_cost: 10000)
    @sale_b = Sale.create!(family: @family_b, client_name: "Other Client")
    @sale_item_b = SaleItem.create!(sale: @sale_b, product: @product_b, quantity: 2, unit_price: 15000)
    @recurring_transaction_b = RecurringTransaction.create!(family: @family_b, name: "Other Recurring", amount: 100000, currency: "pyg", expected_day_of_month: 15, last_occurrence_date: Date.current, next_expected_date: 1.month.from_now.to_date)
    @product_stock_movement_b = ProductStockMovement.create!(product: @product_b, quantity_delta: 5, reason: "entrada")

    # Family A records for positive confirmation
    @product_a = Product.create!(family: @family_a, name: "Family A Product", buy_price: 10000, sell_price: 15000, stock: 10)
    @purchase_order_a = PurchaseOrder.create!(family: @family_a, supplier_name: "Family A Supplier")
    @purchase_order_item_a = PurchaseOrderItem.create!(purchase_order: @purchase_order_a, product: @product_a, quantity: 5, unit_cost: 10000)
    @sale_a = Sale.create!(family: @family_a, client_name: "Family A Client")
    @sale_item_a = SaleItem.create!(sale: @sale_a, product: @product_a, quantity: 2, unit_price: 15000)
    @recurring_transaction_a = RecurringTransaction.create!(family: @family_a, name: "Family A Recurring", amount: 100000, currency: "pyg", expected_day_of_month: 15, last_occurrence_date: Date.current, next_expected_date: 1.month.from_now.to_date)
    @product_stock_movement_a = ProductStockMovement.create!(product: @product_a, quantity_delta: 5, reason: "entrada")
  end

  test "when app.current_family_id session variable is set, raw SQL and ActiveRecord queries cannot access family_b records" do
    ActiveRecord::Base.connection.execute("SET ROLE app_user")
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
    assert_nil FleetVehicle.find_by(id: @fleet_vehicle_b.id)
    assert_nil Product.find_by(id: @product_b.id)
    assert_nil PurchaseOrder.find_by(id: @purchase_order_b.id)
    assert_nil Sale.find_by(id: @sale_b.id)
    assert_nil RecurringTransaction.find_by(id: @recurring_transaction_b.id)

    # Positive assertions for Family A
    assert_equal @product_a, Product.find_by(id: @product_a.id)
    assert_equal @purchase_order_a, PurchaseOrder.find_by(id: @purchase_order_a.id)
    assert_equal @sale_a, Sale.find_by(id: @sale_a.id)
    assert_equal @recurring_transaction_a, RecurringTransaction.find_by(id: @recurring_transaction_a.id)

    # Indirect tables
    assert_nil Entry.find_by(id: @entry_b.id)
    assert_nil Transaction.find_by(id: @transaction_b.id)
    assert_nil BudgetCategory.find_by(id: @budget_category_b.id)
    assert_nil Merchant.find_by(id: @merchant_b.id)
    assert_nil Valuation.find_by(id: @valuation_b.id)
    assert_nil Receivable.find_by(id: @receivable_b.id)
    assert_nil FuelLog.find_by(id: @fuel_log_b.id)
    assert_nil FuelLogLine.find_by(id: "00000000-0000-0000-0000-000000000000") if defined?(FuelLogLine)
    assert_nil PurchaseOrderItem.find_by(id: @purchase_order_item_b.id)
    assert_nil SaleItem.find_by(id: @sale_item_b.id)
    assert_nil ProductStockMovement.find_by(id: @product_stock_movement_b.id)

    # Positive assertions for Family A indirect tables
    assert_equal @purchase_order_item_a, PurchaseOrderItem.find_by(id: @purchase_order_item_a.id)
    assert_equal @sale_item_a, SaleItem.find_by(id: @sale_item_a.id)
    assert_equal @product_stock_movement_a, ProductStockMovement.find_by(id: @product_stock_movement_a.id)

    # Raw SQL queries bypassing Rails model scoping
    raw_accounts = ActiveRecord::Base.connection.execute("SELECT * FROM accounts WHERE id = '#{@account_b.id}'")
    assert_equal 0, raw_accounts.count

    raw_entries = ActiveRecord::Base.connection.execute("SELECT * FROM entries WHERE id = '#{@entry_b.id}'")
    assert_equal 0, raw_entries.count

    raw_transactions = ActiveRecord::Base.connection.execute("SELECT * FROM transactions WHERE id = '#{@transaction_b.id}'")
    assert_equal 0, raw_transactions.count

    raw_fleet_vehicles = ActiveRecord::Base.connection.execute("SELECT * FROM fleet_vehicles WHERE id = '#{@fleet_vehicle_b.id}'")
    assert_equal 0, raw_fleet_vehicles.count

    raw_fuel_logs = ActiveRecord::Base.connection.execute("SELECT * FROM fuel_logs WHERE id = '#{@fuel_log_b.id}'")
    assert_equal 0, raw_fuel_logs.count

    if ActiveRecord::Base.connection.table_exists?("fuel_log_lines")
      raw_fuel_log_lines = ActiveRecord::Base.connection.execute("SELECT * FROM fuel_log_lines WHERE fuel_log_id = '#{@fuel_log_b.id}'")
      assert_equal 0, raw_fuel_log_lines.count
    end

    # Raw SQL queries for business active tables
    raw_products = ActiveRecord::Base.connection.execute("SELECT * FROM products WHERE id = '#{@product_b.id}'")
    assert_equal 0, raw_products.count

    raw_purchase_orders = ActiveRecord::Base.connection.execute("SELECT * FROM purchase_orders WHERE id = '#{@purchase_order_b.id}'")
    assert_equal 0, raw_purchase_orders.count

    raw_sales = ActiveRecord::Base.connection.execute("SELECT * FROM sales WHERE id = '#{@sale_b.id}'")
    assert_equal 0, raw_sales.count

    raw_recurring_transactions = ActiveRecord::Base.connection.execute("SELECT * FROM recurring_transactions WHERE id = '#{@recurring_transaction_b.id}'")
    assert_equal 0, raw_recurring_transactions.count

    raw_purchase_order_items = ActiveRecord::Base.connection.execute("SELECT * FROM purchase_order_items WHERE id = '#{@purchase_order_item_b.id}'")
    assert_equal 0, raw_purchase_order_items.count

    raw_sale_items = ActiveRecord::Base.connection.execute("SELECT * FROM sale_items WHERE id = '#{@sale_item_b.id}'")
    assert_equal 0, raw_sale_items.count

    raw_stock_movements = ActiveRecord::Base.connection.execute("SELECT * FROM product_stock_movements WHERE id = '#{@product_stock_movement_b.id}'")
    assert_equal 0, raw_stock_movements.count
  ensure
    ActiveRecord::Base.connection.execute("RESET app.current_family_id") rescue nil
    ActiveRecord::Base.connection.execute("RESET ROLE") rescue nil
  end

  test "inserting a new transaction, valuation, or receivable succeeds under the restricted role with RLS family context set" do
    # Regression test: transactions/valuations/receivables are inserted before
    # the row that links them to a family exists yet (Rails saves a
    # delegated_type's entryable/accountable before its owner). A prior
    # policy shape (id IN (SELECT ... FROM entries/accounts WHERE ...))
    # let the INSERT itself through via WITH CHECK (true), but Postgres also
    # requires the SELECT policy to pass for INSERT ... RETURNING (which the
    # pg adapter always uses to learn generated columns) -- and that join
    # could never match yet, so every insert into these 3 tables failed in
    # production the moment the app stopped connecting as a role that
    # bypasses RLS. See app/models/entry.rb and app/models/account.rb for
    # the family_id propagation that fixes this.
    ActiveRecord::Base.connection.execute("SET ROLE app_user")
    ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql([ "SET app.current_family_id = ?", @family_a.id ])
    )

    account_a = Account.create!(family: @family_a, name: "RLS insert test account", currency: "USD", balance: 0, accountable: Depository.new)

    entry = account_a.entries.new(name: "RLS insert test transaction", date: Date.current, amount: 42, currency: "USD", entryable: Transaction.new)
    assert entry.save, entry.errors.full_messages.to_s
    assert_equal @family_a.id, entry.entryable.family_id

    valuation_entry = account_a.entries.new(name: "RLS insert test valuation", date: Date.current, amount: 100, currency: "USD", entryable: Valuation.new(kind: "reconciliation"))
    assert valuation_entry.save, valuation_entry.errors.full_messages.to_s
    assert_equal @family_a.id, valuation_entry.entryable.family_id

    receivable_account = @family_a.accounts.new(name: "RLS insert test receivable", currency: "USD", balance: 0, accountable: Receivable.new(total_amount: 100))
    assert receivable_account.save, receivable_account.errors.full_messages.to_s
    assert_equal @family_a.id, receivable_account.accountable.family_id
  ensure
    ActiveRecord::Base.connection.execute("RESET app.current_family_id") rescue nil
    ActiveRecord::Base.connection.execute("RESET ROLE") rescue nil
  end

  test "around_action sets app.current_family_id context automatically on controller requests" do
    sign_in @user_a

    get accounts_path
    assert_response :success
  end

  test "app.current_family_id is reset on the connection after the request completes, so a reused pooled connection never carries a stale family context into the next request" do
    sign_in @user_a

    get accounts_path
    assert_response :success

    reset_value = ActiveRecord::Base.connection.select_value("SELECT current_setting('app.current_family_id', true)")
    assert_predicate reset_value.to_s, :empty?
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
    sync_a = Sync.create!(syncable: @family_a.accounts.first || Account.create!(family: @family_a, name: "Family A Acc", currency: "USD", balance: 100, accountable: Depository.new))

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
    account_a = Account.create!(family: @family_a, name: "Family A Checking", currency: "USD", balance: 500, accountable: Depository.new)
    entry_a = Entry.create!(account: account_a, amount: -100, date: 1.month.ago.to_date, name: "Netflix Subscription", currency: account_a.currency, entryable: Transaction.new)

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
    account_a = Account.create!(family: @family_a, name: "Acc A", currency: "USD", balance: 200, accountable: Depository.new)
    balance_a = account_a.balances.create!(date: Date.current, balance: 200, currency: "USD")
    balance_b = @account_b.balances.create!(date: Date.current, balance: 1000, currency: "USD")

    ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql([ "SET app.current_family_id = ?", @family_a.id ])
    )

    DataCacheClearJob.perform_now(@family_a)

    # Context should be restored and balance_b intact
    ActiveRecord::Base.connection.execute("RESET app.current_family_id")
    assert_nil Balance.find_by(id: balance_a.id)
    assert_not_nil Balance.find_by(id: balance_b.id)
  end
end
