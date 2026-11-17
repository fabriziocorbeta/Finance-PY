# frozen_string_literal: true

balance_money = account.balance_money
cash_balance_money = account.cash_balance_money

json.id account.id
json.name account.name
json.balance balance_money.format
json.balance_cents((balance_money.amount * balance_money.currency.minor_unit_conversion).round(0).to_i)
json.cash_balance cash_balance_money.format
json.cash_balance_cents((cash_balance_money.amount * cash_balance_money.currency.minor_unit_conversion).round(0).to_i)
json.currency account.currency
json.classification account.classification
json.account_type account.accountable_type&.underscore
json.subtype account.subtype
json.status account.status
json.institution_name account.institution_name
json.institution_domain account.institution_domain
json.card_identifier account.card_identifier
json.created_at account.created_at.iso8601
json.updated_at account.updated_at.iso8601

# Type-specific fields the web's account detail pages show (loan rate/term,
# credit card APR/limit, vehicle make/model) but the generic fields above
# never exposed -- clients previously had no way to get these without
# hardcoding one request per Accountable controller. `subtype` is already
# covered by account.subtype above, so it's omitted here to avoid
# duplicating it under each type.
case account.accountable_type
when "Loan"
  loan = account.accountable
  json.loan_details do
    json.rate_type loan.rate_type
    json.interest_rate loan.interest_rate&.to_f
    json.term_months loan.term_months
    json.initial_balance loan.initial_balance&.to_f
    json.amortization_method loan.amortization_method
  end
when "CreditCard"
  credit_card = account.accountable
  json.credit_card_details do
    json.available_credit credit_card.available_credit&.to_f
    json.minimum_payment credit_card.minimum_payment&.to_f
    json.apr credit_card.apr&.to_f
    json.annual_fee credit_card.annual_fee&.to_f
    json.expiration_date credit_card.expiration_date
  end
when "Vehicle"
  vehicle = account.accountable
  json.vehicle_details do
    json.make vehicle.make
    json.model vehicle.model
    json.year vehicle.year
    json.mileage_value vehicle.mileage_value
    json.mileage_unit vehicle.mileage_unit
  end
when "Crypto"
  json.crypto_details do
    json.tax_treatment account.accountable.tax_treatment
  end
end
