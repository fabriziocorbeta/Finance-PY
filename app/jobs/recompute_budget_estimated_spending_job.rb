class RecomputeBudgetEstimatedSpendingJob < ApplicationJob
  queue_as :low_priority

  def perform(family_id:, start_date: nil)
    family = Family.find_by(id: family_id)
    return unless family

    budgets = family.budgets
    budgets = budgets.where("end_date >= ?", Date.parse(start_date.to_s)) if start_date.present?

    budgets.find_each(&:recompute_values!)
  end
end
