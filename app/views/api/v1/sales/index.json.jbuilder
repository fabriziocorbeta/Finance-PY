# frozen_string_literal: true

json.data @sales do |sale|
  json.partial! "api/v1/sales/sale", sale: sale
end

json.meta do
  json.current_page @pagy.page
  json.next_page @pagy.next
  json.prev_page @pagy.prev
  json.total_pages @pagy.pages
  json.total_count @pagy.count
  json.per_page @per_page
end
