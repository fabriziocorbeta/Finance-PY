# frozen_string_literal: true

json.id fuel_log.id
json.fleet_vehicle_id fuel_log.fleet_vehicle_id
json.account_id fuel_log.account_id
json.logged_at fuel_log.logged_at.iso8601
json.odometer fuel_log.odometer
json.liters fuel_log.liters
json.cost fuel_log.cost
json.notes fuel_log.notes
json.entry_id fuel_log.entry_id
json.created_at fuel_log.created_at.iso8601
json.updated_at fuel_log.updated_at.iso8601

json.fuel_log_lines fuel_log.fuel_log_lines do |line|
  json.id line.id
  json.fuel_type line.fuel_type
  json.brand line.brand
  json.liters line.liters
  json.cost line.cost
end
