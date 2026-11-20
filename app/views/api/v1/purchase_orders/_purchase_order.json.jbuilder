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
json.has_invoice_photo purchase_order.invoice_photo.attached?
if purchase_order.invoice_photo.attached?
  json.invoice_photo do
    json.filename purchase_order.invoice_photo.filename.to_s
    json.content_type purchase_order.invoice_photo.content_type
    json.byte_size purchase_order.invoice_photo.byte_size
    json.url "/api/v1/purchase_orders/#{purchase_order.id}/invoice_photo"
  end
else
  json.invoice_photo nil
end
json.created_at purchase_order.created_at.iso8601
json.updated_at purchase_order.updated_at.iso8601

json.purchase_order_items purchase_order.purchase_order_items do |item|
  json.partial! "api/v1/purchase_orders/purchase_order_item", purchase_order_item: item
end
