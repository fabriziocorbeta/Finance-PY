# frozen_string_literal: true

money_to_minor_units = lambda do |money|
  (money.amount * money.currency.minor_unit_conversion).round(0).to_i if money
end

bc = budget_category

json.id bc.id
json.budget_id bc.budget_id
json.category_id bc.category.id
json.category_name bc.category.name
json.category_color bc.category.color
json.category_icon bc.category.lucide_icon
json.category_parent_id bc.category.parent_id
json.subcategory bc.subcategory?
json.inherits_parent_budget bc.inherits_parent_budget?

json.budgeted_spending bc.budgeted_spending
json.budgeted_spending_cents money_to_minor_units.call(bc.budgeted_spending_money)
json.actual_spending bc.actual_spending
json.actual_spending_cents money_to_minor_units.call(bc.actual_spending_money)
json.available_to_spend bc.available_to_spend
json.available_to_spend_cents money_to_minor_units.call(bc.available_to_spend_money)
json.avg_monthly_expense bc.avg_monthly_expense
json.avg_monthly_expense_cents money_to_minor_units.call(bc.avg_monthly_expense_money)
json.median_monthly_expense bc.median_monthly_expense
json.median_monthly_expense_cents money_to_minor_units.call(bc.median_monthly_expense_money)

json.percent_of_budget_spent bc.percent_of_budget_spent
json.bar_width_percent bc.bar_width_percent
json.over_budget bc.over_budget?
json.near_limit bc.near_limit?
json.budgeted bc.budgeted?

if (daily = bc.suggested_daily_spending)
  json.suggested_daily_spending do
    json.amount daily[:amount].amount
    json.amount_cents money_to_minor_units.call(daily[:amount])
    json.days_remaining daily[:days_remaining]
  end
end
