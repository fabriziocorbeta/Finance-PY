# frozen_string_literal: true

json.data @purchase_orders do |purchase_order|
  json.partial! "api/v1/purchase_orders/purchase_order", purchase_order: purchase_order
end

json.meta do
  json.current_page @pagy.page
  json.next_page @pagy.next
  json.prev_page @pagy.prev
  json.total_pages @pagy.pages
  json.total_count @pagy.count
  json.per_page @per_page
end
