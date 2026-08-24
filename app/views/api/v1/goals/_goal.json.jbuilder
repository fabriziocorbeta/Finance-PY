# frozen_string_literal: true

money_to_minor_units = lambda do |money|
  (money.amount * money.currency.minor_unit_conversion).round(0).to_i if money
end

json.extract! goal, :id, :name, :target_amount, :currency, :target_date, :color, :icon, :notes, :state, :progress_basis

json.current_balance goal.current_balance
json.current_balance_cents money_to_minor_units.call(goal.current_balance_money)

json.remaining_amount goal.remaining_amount
json.remaining_amount_cents money_to_minor_units.call(goal.remaining_amount_money)

json.progress_percent goal.progress_percent
