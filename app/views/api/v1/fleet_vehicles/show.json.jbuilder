# frozen_string_literal: true

json.data do
  json.partial! "api/v1/fleet_vehicles/fleet_vehicle", fleet_vehicle: @fleet_vehicle
end
