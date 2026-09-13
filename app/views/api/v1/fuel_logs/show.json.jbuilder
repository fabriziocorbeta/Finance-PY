# frozen_string_literal: true

json.data do
  json.partial! "api/v1/fuel_logs/fuel_log", fuel_log: @fuel_log
end
