# frozen_string_literal: true

price_money = Money.new(holding.price, holding.currency)
amount_money = holding.amount_money

json.id holding.id
json.date holding.date
json.qty holding.qty
json.price price_money.format
json.price_cents (price_money.amount * price_money.currency.minor_unit_conversion).round(0).to_i
json.amount amount_money.format
json.amount_cents (amount_money.amount * amount_money.currency.minor_unit_conversion).round(0).to_i
json.currency holding.currency
json.cost_basis_source holding.cost_basis_source

json.account do
  json.id holding.account.id
  json.name holding.account.name
  json.account_type holding.account.accountable_type.underscore
end

json.security do
  json.id holding.security.id
  json.ticker holding.security.ticker
  json.name holding.security.name
end

avg = holding.avg_cost
json.avg_cost avg ? avg.format : nil
json.avg_cost_cents avg ? (avg.amount * avg.currency.minor_unit_conversion).round(0).to_i : nil

json.created_at holding.created_at.iso8601
json.updated_at holding.updated_at.iso8601
