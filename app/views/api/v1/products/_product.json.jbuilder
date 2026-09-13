# frozen_string_literal: true

json.id product.id
json.name product.name
json.sku product.sku
json.category product.category
json.supplier product.supplier
json.buy_price product.buy_price.to_f
json.sell_price product.sell_price.to_f
json.currency product.currency
json.stock product.stock
json.min_stock product.min_stock
json.description product.description
json.created_at product.created_at.iso8601
json.updated_at product.updated_at.iso8601
