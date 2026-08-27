# frozen_string_literal: true

entry = transaction.entry

json.id transaction.id
json.date entry.date

# Agent/automation-friendly numeric fields (avoid localized parsing and clarify sign)
# `amount` in v1 is a localized string and may follow an accounting sign convention.
# Expose minor units (cents) as integers to make the API agent-friendly.
# Uses currency.minor_unit_conversion (e.g. 100 for USD/EUR, 1 for JPY, 1000 for KWD).
amount_money = entry.amount_money
json.amount amount_money.format

conversion_factor = amount_money.currency.minor_unit_conversion
amount_cents = (amount_money.amount * conversion_factor).round(0).to_i.abs
json.amount_cents amount_cents
json.signed_amount_cents(entry.classification == "income" ? amount_cents : -amount_cents)

json.currency entry.currency
json.name entry.name
json.notes entry.notes
json.classification entry.classification

# Account information
account = entry.account
json.account do
  json.id account.id
  json.name account.name
  json.account_type account.accountable_type.underscore
end

# Category information
category = transaction.category
if category.present?
  json.category do
    json.id category.id
    json.name category.name
    json.color category.color
    json.icon category.lucide_icon
  end
else
  json.category nil
end

# Merchant information
merchant = transaction.merchant
if merchant.present?
  json.merchant do
    json.id merchant.id
    json.name merchant.name
  end
else
  json.merchant nil
end

# Tags
json.tags transaction.tags do |tag|
  json.id tag.id
  json.name tag.name
  json.color tag.color
end

# Transfer information (if this transaction is part of a transfer)
transfer = transaction.transfer
if transfer.present?
  inflow_entry = transfer.inflow_transaction&.entry
  json.transfer do
    json.id transfer.id
    json.amount transfer.amount_abs&.format
    json.currency inflow_entry&.currency

    # Other transaction in the transfer
    if transfer.inflow_transaction == transaction
      other_transaction = transfer.outflow_transaction
    else
      other_transaction = transfer.inflow_transaction
    end

    if other_transaction.present?
      other_entry = other_transaction.entry
      other_account = other_entry&.account
      if other_account.present?
        json.other_account do
          json.id other_account.id
          json.name other_account.name
          json.account_type other_account.accountable_type.underscore
        end
      else
        json.other_account nil
      end
    end
  end
else
  json.transfer nil
end

# Additional metadata
json.created_at transaction.created_at.iso8601
json.updated_at transaction.updated_at.iso8601
