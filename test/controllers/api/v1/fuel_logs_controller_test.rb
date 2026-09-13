# frozen_string_literal: true

require "test_helper"

class Api::V1::FuelLogsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:family_admin)
    @family = @user.family

    @user.api_keys.active.destroy_all
    @api_key = ApiKey.create!(
      user: @user,
      name: "Test Read Key",
      scopes: [ "read" ],
      source: "web",
      display_key: "test_read_#{SecureRandom.hex(8)}"
    )

    @write_api_key = ApiKey.create!(
      user: @user,
      name: "Test Write Key",
      scopes: [ "read_write" ],
      source: "mobile",
      display_key: "test_write_#{SecureRandom.hex(8)}"
    )

    Redis.new.del("api_rate_limit:#{@api_key.id}")
    Redis.new.del("api_rate_limit:#{@write_api_key.id}")

    @account = accounts(:depository)
    @vehicle = FleetVehicle.create!(
      family: @family,
      plate: "FLT-001",
      brand: "Toyota",
      model: "Corolla",
      year: 2021
    )
  end

  test "should create fuel log and associated account entry" do
    assert_difference -> { FuelLog.count } => 1, -> { Entry.count } => 1 do
      post api_v1_fleet_vehicle_fuel_logs_url(@vehicle),
           params: {
             fuel_log: {
               account_id: @account.id,
               logged_at: Date.current.iso8601,
               odometer: 15000,
               notes: "Carga completa",
               fuel_log_lines_attributes: [
                 { fuel_type: "nafta", brand: "Podium", liters: 45.0, cost: 350000.0 }
               ]
             }
           },
           headers: api_headers(@write_api_key)
    end

    assert_response :created
    json_response = JSON.parse(response.body)["data"]
    assert_equal @vehicle.id, json_response["fleet_vehicle_id"]
    assert_equal "45.0", json_response["liters"]
    assert_equal "350000.0", json_response["cost"]

    # Verify Entry was created with category "Combustible"
    fuel_log = FuelLog.find(json_response["id"])
    assert_not_nil fuel_log.entry
    assert_equal "Combustible - FLT-001", fuel_log.entry.name
    assert_equal 350000.0, fuel_log.entry.amount
    assert_equal "Combustible", fuel_log.entry.entryable.category.name
  end

  test "should update fuel log" do
    fuel_log = @vehicle.fuel_logs.create!(
      account: @account,
      logged_at: Date.current,
      fuel_log_lines_attributes: [ { fuel_type: "nafta", liters: 40, cost: 300000 } ]
    )

    patch api_v1_fleet_vehicle_fuel_log_url(@vehicle, fuel_log),
          params: {
            fuel_log: {
              odometer: 18000,
              fuel_log_lines_attributes: [
                { id: fuel_log.fuel_log_lines.first.id, fuel_type: "nafta", liters: 50, cost: 400000 }
              ]
            }
          },
          headers: api_headers(@write_api_key)

    assert_response :success
    fuel_log.reload
    assert_equal 18000, fuel_log.odometer
    assert_equal 50.0, fuel_log.liters
    assert_equal 400000.0, fuel_log.cost
    assert_equal 400000.0, fuel_log.entry.amount
  end

  test "should destroy fuel log" do
    fuel_log = @vehicle.fuel_logs.create!(
      account: @account,
      logged_at: Date.current,
      fuel_log_lines_attributes: [ { fuel_type: "nafta", liters: 40, cost: 300000 } ]
    )

    assert_difference -> { FuelLog.count } => -1, -> { Entry.count } => -1 do
      delete api_v1_fleet_vehicle_fuel_log_url(@vehicle, fuel_log), headers: api_headers(@write_api_key)
    end

    assert_response :success
  end

  test "should not create fuel log for vehicle in another family" do
    other_family = Family.create!(name: "Other Family", currency: "USD", locale: "en")
    other_vehicle = FleetVehicle.create!(
      family: other_family,
      plate: "OTH-999",
      brand: "Ford",
      model: "F150",
      year: 2020
    )

    post api_v1_fleet_vehicle_fuel_logs_url(other_vehicle),
         params: {
           fuel_log: {
             account_id: @account.id,
             logged_at: Date.current.iso8601,
             fuel_log_lines_attributes: [ { fuel_type: "diesel", liters: 50, cost: 200000 } ]
           }
         },
         headers: api_headers(@write_api_key)

    assert_response :not_found
  end

  private

    def api_headers(api_key)
      { "X-Api-Key" => api_key.plain_key }
    end
end
