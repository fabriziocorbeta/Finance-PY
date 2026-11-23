require "test_helper"

module Dashboard
  class WidgetsComponentTest < ViewComponent::TestCase
    setup do
      @family = families(:empty)
      @family.update!(currency: "PYG")
    end

    test "AvailableToSpendComponent subtracts credit card balance from depository balance" do
      @family.accounts.create!(
        name: "Banco Itaú",
        balance: 2_000_000,
        currency: "PYG",
        accountable: Depository.new
      )
      @family.accounts.create!(
        name: "Tarjeta Visa",
        balance: 500_000,
        currency: "PYG",
        accountable: CreditCard.new
      )

      component = Dashboard::AvailableToSpendComponent.new(family: @family)
      assert_equal Money.new(1_500_000, "PYG"), component.available_money
      assert_equal 1, component.liquid_accounts_count
      assert_not component.low_balance?

      render_inline(component)
      assert_selector "turbo-frame#widget_available_to_spend"
      assert_text "Saludable"
    end

    test "RecentExpensesComponent renders empty state when no expenses" do
      component = Dashboard::RecentExpensesComponent.new(family: @family)
      assert_equal Money.new(0, "PYG"), component.total_recent_money

      render_inline(component)
      assert_selector "turbo-frame#widget_recent_expenses"
      assert_text "No se registraron gastos recientes."
    end

    test "BudgetStatusComponent handles uninitialized budget gracefully" do
      component = Dashboard::BudgetStatusComponent.new(family: @family)
      assert_equal 0.0, component.percentage_used
      assert_equal "Sin presupuesto definido", component.status_label

      render_inline(component)
      assert_selector "turbo-frame#widget_budget_status"
      assert_text "Sin presupuesto definido"
    end

    test "SalesSummaryComponent handles empty sales gracefully" do
      component = Dashboard::SalesSummaryComponent.new(family: @family)
      assert_equal 0, component.sales_count
      assert_equal Money.new(0, "PYG"), component.total_sales_money
      assert_equal Money.new(0, "PYG"), component.average_ticket_money
      assert_nil component.growth_percentage

      render_inline(component)
      assert_selector "turbo-frame#widget_sales_summary"
      assert_text "0 ventas"
    end
  end
end
