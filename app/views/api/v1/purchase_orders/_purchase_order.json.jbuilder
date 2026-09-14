# frozen_string_literal: true

json.id purchase_order.id
json.order_number purchase_order.order_number
json.supplier_name purchase_order.supplier_name
json.status purchase_order.status
json.currency purchase_order.currency
json.expected_date purchase_order.expected_date
json.notes purchase_order.notes
json.account_id purchase_order.account_id
json.total purchase_order.total.to_f
json.created_at purchase_order.created_at.iso8601
json.updated_at purchase_order.updated_at.iso8601

json.purchase_order_items purchase_order.purchase_order_items do |item|
  json.partial! "api/v1/purchase_orders/purchase_order_item", purchase_order_item: item
end
