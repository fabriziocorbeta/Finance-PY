# frozen_string_literal: true

json.id sale_item.id
json.sale_id sale_item.sale_id
json.product_id sale_item.product_id
json.product_name sale_item.product&.name
json.product_sku sale_item.product&.sku
json.quantity sale_item.quantity
json.unit_price sale_item.unit_price.to_f
json.subtotal sale_item.subtotal.to_f
json.created_at sale_item.created_at.iso8601
json.updated_at sale_item.updated_at.iso8601
