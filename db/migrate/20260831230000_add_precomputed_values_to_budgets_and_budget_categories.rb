class AddPrecomputedValuesToBudgetsAndBudgetCategories < ActiveRecord::Migration[7.2]
  def change
    add_column :budgets, :precomputed_estimated_spending, :decimal, precision: 19, scale: 4
    add_column :budget_categories, :precomputed_actual_spending, :decimal, precision: 19, scale: 4
    add_column :budget_categories, :precomputed_available_to_spend, :decimal, precision: 19, scale: 4
  end
end
