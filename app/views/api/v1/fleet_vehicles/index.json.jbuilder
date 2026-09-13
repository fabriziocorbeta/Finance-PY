# frozen_string_literal: true

json.data @fleet_vehicles do |fleet_vehicle|
  json.partial! "api/v1/fleet_vehicles/fleet_vehicle", fleet_vehicle: fleet_vehicle
end

json.meta do
  json.current_page @pagy.page
  json.next_page @pagy.next
  json.prev_page @pagy.prev
  json.total_pages @pagy.pages
  json.total_count @pagy.count
  json.per_page @per_page
end
