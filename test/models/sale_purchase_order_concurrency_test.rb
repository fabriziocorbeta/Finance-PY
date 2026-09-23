require "test_helper"

# Real concurrency test: two separate DB connections (one per thread) racing
# against the SAME row, so we exercise actual Postgres row locking instead of
# Ruby-level mocking. Needs use_transactional_tests = false because the two
# threads must each see the other's committed writes -- the default
# transactional-fixtures rollback would hide that entirely and the second
# connection would just block forever / see stale data.
#
# NOTE (per E3 task instructions): this test runs with the app's normal test
# role, which is a Postgres superuser and therefore bypasses RLS. It verifies
# the locking/idempotency fix itself, not its interaction with FORCE RLS on
# products/sales/purchase_orders. RLS enforcement on these tables is covered
# separately by test/integration/row_level_security_test.rb; a non-superuser
# (SET ROLE) concurrent test combining both is NOT included here -- flagging
# as an explicit gap rather than silently skipping it.
class SalePurchaseOrderConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @family = Family.create!(name: "Concurrency Test Family #{SecureRandom.hex(4)}", default_account_sharing: "shared")
    @account = Account.create!(family: @family, name: "Cuenta", currency: "PYG", balance: 0, accountable: Depository.new)
  end

  teardown do
    # fixtures :all does NOT cover sales/purchase_orders/product_stock_movements
    # (no fixture files for them), so under use_transactional_tests = false
    # nothing rolls these back automatically. Clean up explicitly so the next
    # test's fixture reload (which DOES cover families/accounts/products)
    # doesn't trip over orphaned rows referencing IDs we created here.
    #
    # session_replication_role = replica disables FK/trigger enforcement for
    # this session so we don't have to enumerate every table that might
    # reference this family (transactions via entries.entryable, categories,
    # etc.) in exact dependency order -- a single scoped DELETE per table is
    # enough, and a half-failed teardown can't corrupt the next test either.
    next unless @family

    ActiveRecord::Base.connection.execute("SET session_replication_role = replica;")
    ActiveRecord::Base.connection.execute(<<~SQL)
      DELETE FROM product_stock_movements WHERE product_id IN (SELECT id FROM products WHERE family_id = '#{@family.id}');
      DELETE FROM sale_items WHERE sale_id IN (SELECT id FROM sales WHERE family_id = '#{@family.id}');
      DELETE FROM purchase_order_items WHERE purchase_order_id IN (SELECT id FROM purchase_orders WHERE family_id = '#{@family.id}');
      DELETE FROM sales WHERE family_id = '#{@family.id}';
      DELETE FROM purchase_orders WHERE family_id = '#{@family.id}';
      DELETE FROM transactions WHERE family_id = '#{@family.id}';
      DELETE FROM entries WHERE account_id IN (SELECT id FROM accounts WHERE family_id = '#{@family.id}');
      DELETE FROM categories WHERE family_id = '#{@family.id}';
      DELETE FROM products WHERE family_id = '#{@family.id}';
      DELETE FROM accounts WHERE family_id = '#{@family.id}';
      DELETE FROM families WHERE id = '#{@family.id}';
    SQL
  ensure
    ActiveRecord::Base.connection.execute("SET session_replication_role = DEFAULT;") rescue nil
  end

  test "two concurrent complete! calls on the SAME sale only decrement stock and create one entry once" do
    product = Product.create!(family: @family, name: "Producto A", stock: 5, buy_price: 10, sell_price: 20)
    sale = Sale.create!(family: @family, account: @account)
    sale.sale_items.create!(product: product, quantity: 5, unit_price: 20)

    barrier_errors = []
    threads = 2.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          Sale.find(sale.id).complete!
        end
      rescue => e
        barrier_errors << e
      end
    end
    threads.each(&:join)

    assert barrier_errors.empty?, "expected both calls to no-op cleanly, got: #{barrier_errors.map(&:message)}"
    assert_equal "completed", sale.reload.status
    assert_equal 1, ProductStockMovement.where(product_id: product.id).count
    assert_equal 0, product.reload.stock
    assert_equal 1, Entry.where(account_id: @account.id).count
  end

  test "two concurrent cancel! calls on the SAME received purchase order only revert stock once" do
    product = Product.create!(family: @family, name: "Producto B", stock: 0, buy_price: 10, sell_price: 20)
    po = PurchaseOrder.create!(family: @family, account: @account)
    po.purchase_order_items.create!(product: product, quantity: 5, unit_cost: 10)
    po.receive!
    assert_equal 5, product.reload.stock

    barrier_errors = []
    threads = 2.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          PurchaseOrder.find(po.id).cancel!
        end
      rescue => e
        barrier_errors << e
      end
    end
    threads.each(&:join)

    assert barrier_errors.empty?, "expected both calls to no-op cleanly, got: #{barrier_errors.map(&:message)}"
    assert_equal "cancelled", po.reload.status
    assert_equal 1, ProductStockMovement.where(product_id: product.id, reason: "salida").count
    assert_equal 0, product.reload.stock
  end

  test "two DIFFERENT sales racing for the last units of the same product: exactly one wins, stock never goes negative" do
    product = Product.create!(family: @family, name: "Producto C", stock: 5, buy_price: 10, sell_price: 20)
    sale_a = Sale.create!(family: @family, account: @account)
    sale_a.sale_items.create!(product: product, quantity: 5, unit_price: 20)
    sale_b = Sale.create!(family: @family, account: @account)
    sale_b.sale_items.create!(product: product, quantity: 5, unit_price: 20)

    outcomes = Queue.new
    threads = [ sale_a, sale_b ].map do |sale|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          Sale.find(sale.id).complete!
          outcomes << :ok
        end
      rescue ActiveRecord::RecordInvalid => e
        outcomes << [ :invalid, e.record.errors.full_messages ]
      end
    end
    threads.each(&:join)

    results = Array.new(2) { outcomes.pop }
    assert_equal 1, results.count(:ok), "expected exactly one sale to complete, got: #{results.inspect}"
    invalid = results.find { |r| r.is_a?(Array) }
    assert invalid, "expected the losing sale to raise a validation error, got: #{results.inspect}"
    assert(invalid[1].any? { |m| m.include?("Insufficient stock") }, invalid[1].inspect)

    assert_equal 0, product.reload.stock
    assert product.stock >= 0
  end
end
