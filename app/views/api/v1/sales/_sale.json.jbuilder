# frozen_string_literal: true

json.id sale.id
json.sale_number sale.sale_number
json.client_name sale.client_name
json.status sale.status
json.currency sale.currency
json.payment_method sale.payment_method
json.invoice_number sale.invoice_number
json.condition sale.condition
json.notes sale.notes
json.delivery_address sale.delivery_address
json.delivery_date sale.delivery_date
json.carrier sale.carrier
json.account_id sale.account_id
json.total sale.total.to_f
json.created_at sale.created_at.iso8601
json.updated_at sale.updated_at.iso8601

json.sale_items sale.sale_items do |item|
  json.partial! "api/v1/sales/sale_item", sale_item: item
end
