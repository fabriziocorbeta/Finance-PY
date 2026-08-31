class RecomputeBudgetEstimatedSpendingJob < ApplicationJob
  queue_as :low_priority

  def perform(family_id:, start_date: nil, end_date: nil)
    family = Family.find_by(id: family_id)
    return unless family

    budgets = family.budgets
    if start_date.present?
      # An entry mutation affects median estimated_spending for the entry's budget
      # and subsequent budgets within the lookback window.
      window_end = (Date.parse(start_date.to_s) + 12.months).end_of_month
      budgets = budgets.where("end_date >= ?", Date.parse(start_date.to_s))
    end

    budgets.find_each do |budget|
      budget.recompute_values!
    end
  end
end
