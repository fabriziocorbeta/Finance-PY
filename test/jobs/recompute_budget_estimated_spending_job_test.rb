require "test_helper"

class RecomputeBudgetEstimatedSpendingJobTest < ActiveJob::TestCase
  test "recomputes estimated spending for all family budgets" do
    family = families(:dylan_family)
    budget1 = Budget.find_or_bootstrap(family, start_date: 1.month.ago.beginning_of_month)
    budget2 = Budget.find_or_bootstrap(family, start_date: Date.current.beginning_of_month)

    budget1.update_columns(precomputed_estimated_spending: nil)
    budget2.update_columns(precomputed_estimated_spending: nil)

    RecomputeBudgetEstimatedSpendingJob.perform_now(family_id: family.id)

    budget1.reload
    budget2.reload

    assert_equal budget1.live_estimated_spending, budget1.estimated_spending
    assert_equal budget2.live_estimated_spending, budget2.estimated_spending
  end

  test "entry and transaction changes trigger job" do
    family = families(:dylan_family)
    account = family.accounts.first

    assert_enqueued_with(job: RecomputeBudgetEstimatedSpendingJob, args: [ { family_id: family.id, start_date: Date.current.to_s } ]) do
      account.entries.create!(
        date: Date.current,
        amount: 50.00,
        currency: "USD",
        name: "Job trigger test",
        entryable: Transaction.new
      )
    end
  end

  test "budgets:recompute_all rake task backfills correctly" do
    Rails.application.load_tasks unless Rake::Task.task_defined?("budgets:recompute_all")

    family = families(:dylan_family)
    budget = Budget.find_or_bootstrap(family, start_date: Date.current.beginning_of_month)
    budget.update_columns(precomputed_estimated_spending: nil)
    budget.budget_categories.update_all(precomputed_actual_spending: nil, precomputed_available_to_spend: nil)

    Rake::Task["budgets:recompute_all"].invoke

    budget.reload
    assert_equal budget.live_estimated_spending, budget.estimated_spending
    budget.budget_categories.reload.each do |bc|
      assert_equal bc.live_actual_spending, bc.actual_spending
      assert_equal bc.live_available_to_spend, bc.available_to_spend
    end
  end
end
