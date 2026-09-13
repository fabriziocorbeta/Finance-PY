# frozen_string_literal: true

json.extract! fleet_vehicle, :id, :family_id, :plate, :brand, :model, :year, :status, :notes, :created_at, :updated_at

json.average_fuel_efficiency fleet_vehicle.average_fuel_efficiency
json.monthly_fuel_consumed fleet_vehicle.monthly_fuel_consumed
json.monthly_distance fleet_vehicle.monthly_distance

recent_logs = fleet_vehicle.fuel_logs.includes(:fuel_log_lines).order(logged_at: :desc, created_at: :desc).limit(20)
json.fuel_logs recent_logs do |fuel_log|
  json.partial! "api/v1/fuel_logs/fuel_log", fuel_log: fuel_log
end
