# frozen_string_literal: true

json.extract! fuel_log, :id, :fleet_vehicle_id, :account_id, :entry_id, :odometer, :logged_at, :notes, :created_at, :updated_at
json.liters fuel_log.liters.to_f
json.cost fuel_log.cost.to_f

json.fuel_log_lines fuel_log.fuel_log_lines do |line|
  json.extract! line, :id, :fuel_log_id, :fuel_type, :brand, :created_at, :updated_at
  json.liters line.liters.to_f
  json.cost line.cost.to_f
end
