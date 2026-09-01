require "test_helper"

class RecomputeBudgetEstimatedSpendingJobTest < ActiveJob::TestCase
  setup do
    @family = families(:dylan_family)
    @budget = budgets(:one)

    @category = Category.create!(
      name: "Test Recompute Job Category #{Time.now.to_f}",
      family: @family,
      color: "#4da568",
      lucide_icon: "utensils"
    )

    @budget_category = BudgetCategory.create!(
      budget: @budget,
      category: @category,
      budgeted_spending: 100,
      currency: "USD"
    )
  end

  test "perform recomputes and persists precomputed values for the family's budgets" do
    assert_nil @budget.reload.precomputed_estimated_spending
    assert_nil @budget_category.reload.precomputed_actual_spending

    RecomputeBudgetEstimatedSpendingJob.perform_now(family_id: @family.id)

    assert_not_nil @budget.reload.precomputed_estimated_spending
    assert_not_nil @budget_category.reload.precomputed_actual_spending
    assert_not_nil @budget_category.reload.precomputed_available_to_spend
  end

  test "perform with start_date only recomputes budgets ending on or after that date" do
    past_budget = Budget.create!(
      family: @family,
      start_date: 3.years.ago.beginning_of_month,
      end_date: 3.years.ago.end_of_month,
      currency: "USD"
    )

    RecomputeBudgetEstimatedSpendingJob.perform_now(family_id: @family.id, start_date: Date.current.to_s)

    assert_not_nil @budget.reload.precomputed_estimated_spending
    assert_nil past_budget.reload.precomputed_estimated_spending
  end

  test "perform does nothing for an unknown family_id" do
    assert_nothing_raised do
      RecomputeBudgetEstimatedSpendingJob.perform_now(family_id: SecureRandom.uuid)
    end
  end
end
