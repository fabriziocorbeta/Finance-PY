# frozen_string_literal: true

json.id @transfer.id
json.status @transfer.status
json.date @transfer.date.iso8601

outflow_entry = @transfer.outflow_transaction.entry
inflow_entry = @transfer.inflow_transaction.entry

json.amount outflow_entry.amount_money.amount.to_f
json.currency outflow_entry.currency

json.from_account do
  json.id outflow_entry.account.id
  json.name outflow_entry.account.name
end

json.to_account do
  json.id inflow_entry.account.id
  json.name inflow_entry.account.name
end
