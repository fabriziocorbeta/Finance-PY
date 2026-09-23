require "test_helper"

class SaleTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @product = products(:dylan_product_1)
    @account = accounts(:depository)
  end

  test "sale_number auto-increments per family" do
    family2 = Family.create!(name: "Another Family", default_account_sharing: "shared")
    account2 = Account.create!(family: family2, name: "Cuenta Family2", currency: "USD", balance: 0, accountable: Depository.new)

    sale1 = Sale.create!(family: @family, account: @account)
    assert_equal 1, sale1.sale_number

    sale2 = Sale.create!(family: @family, account: @account)
    assert_equal 2, sale2.sale_number

    sale3 = Sale.create!(family: family2, account: account2)
    assert_equal 1, sale3.sale_number
  end

  test "total calculates sum of sale items" do
    sale = Sale.create!(family: @family, account: @account)
    sale.sale_items.create!(product: @product, quantity: 2, unit_price: 10)
    sale.sale_items.create!(product: @product, quantity: 3, unit_price: 15)

    assert_equal 65, sale.total
  end

  test "complete! updates status to completed and creates stock movements" do
    sale = Sale.create!(family: @family, account: @account)
    item = sale.sale_items.create!(product: @product, quantity: 2, unit_price: 10)

    assert_difference -> { ProductStockMovement.count }, 1 do
      sale.complete!
    end

    assert_equal "completed", sale.reload.status
    movement = ProductStockMovement.order(:created_at).last
    assert_equal "salida", movement.reason
    assert_equal -2, movement.quantity_delta
    assert_equal @product.id, movement.product_id
  end

  test "complete! creates an income entry on the sale's account" do
    sale = Sale.create!(family: @family, account: @account)
    sale.sale_items.create!(product: @product, quantity: 2, unit_price: 10)

    assert_difference -> { Entry.count }, 1 do
      sale.complete!
    end

    sale.reload
    assert_not_nil sale.entry_id
    assert_equal(-20, sale.entry.amount)
    assert_equal @account.id, sale.entry.account_id
  end

  test "cancel! from completed updates status, creates return stock movements and removes the entry" do
    sale = Sale.create!(family: @family, account: @account)
    item = sale.sale_items.create!(product: @product, quantity: 2, unit_price: 10)
    sale.complete!

    assert_difference -> { ProductStockMovement.count }, 1 do
      assert_difference -> { Entry.count }, -1 do
        sale.cancel!
      end
    end

    assert_equal "cancelled", sale.reload.status
    assert_nil sale.entry_id
    movement = ProductStockMovement.order(:created_at).last
    assert_equal "entrada", movement.reason
    assert_equal 2, movement.quantity_delta
  end

  test "cancel! from draft updates status and does not create stock movements" do
    sale = Sale.create!(family: @family, account: @account)
    item = sale.sale_items.create!(product: @product, quantity: 2, unit_price: 10)

    assert_no_difference -> { ProductStockMovement.count } do
      sale.cancel!
    end

    assert_equal "cancelled", sale.reload.status
  end

  test "complete! converts entry amount when sale currency differs from account currency" do
    ExchangeRate.create!(from_currency: "PYG", to_currency: "USD", rate: 0.00013, date: Date.current)

    sale = Sale.create!(family: @family, account: @account, currency: "pyg")
    sale.sale_items.create!(product: @product, quantity: 1, unit_price: 100_000)

    sale.complete!
    sale.reload

    expected_amount = -(100_000 * BigDecimal("0.00013"))
    assert_equal expected_amount.round(6), sale.entry.amount.round(6)
    assert_equal @account.currency, sale.entry.currency
  end

  test "complete! falls back to raw total when no exchange rate is available for a currency mismatch" do
    sale = Sale.create!(family: @family, account: @account, currency: "pyg")
    sale.sale_items.create!(product: @product, quantity: 2, unit_price: 10)

    sale.complete!
    sale.reload

    # No PYG->USD rate exists in this test environment, so it falls back to
    # the raw (unconverted) total -- same behavior as before this fix for
    # the case where no rate is available.
    assert_equal(-20, sale.entry.amount)
  end

  test "account must belong to the same family" do
    foreign_account = Account.create!(family: Family.create!(name: "Other Family", default_account_sharing: "shared"), name: "Ajena", currency: "USD", balance: 0, accountable: Depository.new)
    sale = Sale.new(family: @family, account: foreign_account)

    assert_not sale.valid?
    assert_includes sale.errors[:account], "must belong to the same family"
  end

  test "status cannot be changed directly" do
    sale = Sale.create!(family: @family, account: @account)

    sale.status = "completed"
    assert_not sale.valid?
    assert_includes sale.errors[:status], "cannot be changed directly. Use complete! or cancel! instead."

    assert_raises(ActiveRecord::RecordInvalid) do
      sale.save!
    end
  end
end
