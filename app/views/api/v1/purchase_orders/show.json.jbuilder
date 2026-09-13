# frozen_string_literal: true

json.data do
  json.partial! "api/v1/purchase_orders/purchase_order", purchase_order: @purchase_order
end
