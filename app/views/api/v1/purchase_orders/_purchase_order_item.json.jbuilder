# frozen_string_literal: true

json.id purchase_order_item.id
json.purchase_order_id purchase_order_item.purchase_order_id
json.product_id purchase_order_item.product_id
json.product_name purchase_order_item.product&.name
json.product_sku purchase_order_item.product&.sku
json.quantity purchase_order_item.quantity
json.unit_cost purchase_order_item.unit_cost.to_f
json.subtotal purchase_order_item.subtotal.to_f
json.created_at purchase_order_item.created_at.iso8601
json.updated_at purchase_order_item.updated_at.iso8601
