# frozen_string_literal: true

json.id fleet_vehicle.id
json.plate fleet_vehicle.plate
json.brand fleet_vehicle.brand
json.model fleet_vehicle.model
json.year fleet_vehicle.year
json.status fleet_vehicle.status
json.notes fleet_vehicle.notes
json.created_at fleet_vehicle.created_at.iso8601
json.updated_at fleet_vehicle.updated_at.iso8601

json.average_fuel_efficiency fleet_vehicle.average_fuel_efficiency
json.monthly_fuel_consumed fleet_vehicle.monthly_fuel_consumed
json.monthly_distance fleet_vehicle.monthly_distance

recent_fuel_logs = fleet_vehicle.fuel_logs.includes(:fuel_log_lines).order(logged_at: :desc, created_at: :desc).limit(20)

json.fuel_logs recent_fuel_logs do |fuel_log|
  json.partial! "api/v1/fleet_vehicles/fuel_log", fuel_log: fuel_log
end
