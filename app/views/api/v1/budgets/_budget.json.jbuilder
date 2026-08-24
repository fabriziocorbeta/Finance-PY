# frozen_string_literal: true

money_to_minor_units = lambda do |money|
  (money.amount * money.currency.minor_unit_conversion).round(0).to_i if money
end

json.extract! budget, :id, :start_date, :end_date, :currency
json.budgeted_spending budget.budgeted_spending.to_f
json.expected_income budget.expected_income.to_f
json.actual_spending budget.actual_spending.to_f
json.actual_spending_cents money_to_minor_units.call(budget.actual_spending_money)
json.allocated_spending budget.allocated_spending.to_f
json.allocated_spending_cents money_to_minor_units.call(budget.allocated_spending_money)
json.available_to_spend budget.available_to_spend.to_f
json.available_to_spend_cents money_to_minor_units.call(budget.available_to_spend_money)
json.percent_of_budget_spent budget.percent_of_budget_spent.to_f.round(1)
json.actual_income budget.actual_income.to_f
json.actual_income_cents money_to_minor_units.call(budget.actual_income_money)
json.remaining_expected_income budget.remaining_expected_income.to_f
json.remaining_expected_income_cents money_to_minor_units.call(budget.remaining_expected_income_money)
