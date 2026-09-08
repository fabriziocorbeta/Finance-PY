# frozen_string_literal: true

money_to_minor_units = lambda do |money|
  (money.amount * money.currency.minor_unit_conversion).round(0).to_i if money
end

json.extract! budget, :id, :start_date, :end_date, :currency
json.budgeted_spending budget.budgeted_spending&.to_f
json.expected_income budget.expected_income&.to_f
json.name budget.name
json.param budget.to_param
json.initialized budget.initialized?
json.current budget.current?
json.previous_budget_param budget.previous_budget_param
json.next_budget_param budget.next_budget_param
json.allocations_valid budget.allocations_valid?

# budgeted_spending/expected_income are numeric(19,4) columns -- ActiveRecord
# maps them to BigDecimal, and the rest of these monetized attributes
# (actual_spending, available_to_spend, etc.) inherit that via arithmetic on
# them. Rails' default JSON encoder renders BigDecimal as a quoted STRING to
# avoid float precision loss -- silently wrong for a numeric API field. Force
# Float explicitly on every one of them (same bug/fix as FleetVehicle#monthly_metrics_series).
json.actual_spending budget.actual_spending.to_f
json.actual_spending_cents money_to_minor_units.call(budget.actual_spending_money)
json.available_to_spend budget.available_to_spend.to_f
json.available_to_spend_cents money_to_minor_units.call(budget.available_to_spend_money)
json.allocated_spending budget.allocated_spending.to_f
json.allocated_spending_cents money_to_minor_units.call(budget.allocated_spending_money)
json.allocated_percent budget.allocated_percent.to_f
json.available_to_allocate budget.available_to_allocate.to_f
json.available_to_allocate_cents money_to_minor_units.call(budget.available_to_allocate_money)
json.percent_of_budget_spent budget.percent_of_budget_spent.to_f

json.actual_income budget.actual_income.to_f
json.actual_income_cents money_to_minor_units.call(budget.actual_income_money)
json.actual_income_percent budget.actual_income_percent.to_f
json.remaining_expected_income budget.remaining_expected_income.to_f
json.remaining_expected_income_cents money_to_minor_units.call(budget.remaining_expected_income_money)
json.surplus_percent budget.surplus_percent.to_f

if budget.initialized?
  json.donut_segments budget.to_donut_segments_json
end

if budget.most_recent_initialized_budget && !budget.initialized?
  json.source_budget do
    json.id budget.most_recent_initialized_budget.id
    json.name budget.most_recent_initialized_budget.name
  end
end

json.categories budget.budget_categories do |bc|
  json.partial! "api/v1/budget_categories/budget_category", budget_category: bc
end
