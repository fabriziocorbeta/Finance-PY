# frozen_string_literal: true

money_to_minor_units = lambda do |money|
  (money.amount * money.currency.minor_unit_conversion).round(0).to_i if money
end

original_balance_money = receivable.original_balance
original_balance_amount = original_balance_money.amount

balance_money = Money.new(receivable.account.balance, receivable.account.currency)
balance_amount = balance_money.amount

paid_amount = [ original_balance_amount - balance_amount, 0.to_d ].max
paid_money = Money.new(paid_amount, receivable.account.currency)

percent_paid = original_balance_amount.zero? ? 0.0 : ((paid_amount / original_balance_amount) * 100).to_f

json.extract! receivable, :id, :total_amount, :installment_count, :due_day
json.balance balance_amount
json.balance_cents money_to_minor_units.call(balance_money)
json.original_balance original_balance_amount
json.original_balance_cents money_to_minor_units.call(original_balance_money)
json.paid_amount paid_amount
json.paid_amount_cents money_to_minor_units.call(paid_money)
json.percent_paid percent_paid
json.name receivable.account.name
json.currency receivable.account.currency
json.notes receivable.account.notes
json.updated_at receivable.account.updated_at
