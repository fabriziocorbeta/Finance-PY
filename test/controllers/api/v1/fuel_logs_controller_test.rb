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

    @vehicle = FleetVehicle.create!(
      family: @family,
      plate: "ABC-123",
      brand: "Toyota",
      model: "Hilux",
      year: 2022
    )

    @account = @family.accounts.create!(
      name: "Caja Chica",
      balance: 10_000,
      currency: "USD",
      owner: @user,
      accountable: Depository.new
    )
  end

  test "should create fuel log and automatically generate transaction entry" do
    assert_difference -> { FuelLog.count } => 1, -> { Entry.count } => 1, -> { Transaction.count } => 1 do
      post api_v1_fleet_vehicle_fuel_logs_url(@vehicle),
           params: {
             fuel_log: {
               account_id: @account.id,
               logged_at: Time.current.iso8601,
               odometer: 15000,
               fuel_log_lines_attributes: [
                 { fuel_type: "nafta", brand: "Super 97", liters: 40, cost: 200 }
               ]
             }
           },
           headers: api_headers(@write_api_key)
    end

    assert_response :created
    json_response = JSON.parse(response.body)["data"]
    assert_equal 40.0, json_response["liters"]
    assert_equal 200.0, json_response["cost"]

    fuel_log = FuelLog.find(json_response["id"])
    assert_not_nil fuel_log.entry
    assert_equal "Combustible - ABC-123", fuel_log.entry.name
    assert_equal 200.0, fuel_log.entry.amount
  end

  test "should update fuel log" do
    fuel_log = @vehicle.fuel_logs.create!(
      account: @account,
      logged_at: Time.current,
      odometer: 10000,
      fuel_log_lines_attributes: [
        { fuel_type: "diesel", brand: "Podium", liters: 50, cost: 300 }
      ]
    )

    patch api_v1_fleet_vehicle_fuel_log_url(@vehicle, fuel_log),
          params: {
            fuel_log: {
              odometer: 10500,
              fuel_log_lines_attributes: [
                { id: fuel_log.fuel_log_lines.first.id, fuel_type: "diesel", liters: 60, cost: 360 }
              ]
            }
          },
          headers: api_headers(@write_api_key)

    assert_response :success
    json_response = JSON.parse(response.body)["data"]
    assert_equal 60.0, json_response["liters"]
    assert_equal 360.0, json_response["cost"]

    fuel_log.reload
    assert_equal 10500, fuel_log.odometer
    assert_equal 360.0, fuel_log.entry.amount
  end

  test "should destroy fuel log and destroy associated transaction entry" do
    fuel_log = @vehicle.fuel_logs.create!(
      account: @account,
      logged_at: Time.current,
      odometer: 10000,
      fuel_log_lines_attributes: [
        { fuel_type: "diesel", brand: "Podium", liters: 50, cost: 300 }
      ]
    )
    entry_id = fuel_log.entry_id

    assert_difference -> { FuelLog.count } => -1, -> { Entry.count } => -1 do
      delete api_v1_fleet_vehicle_fuel_log_url(@vehicle, fuel_log), headers: api_headers(@write_api_key)
    end

    assert_response :success
    assert_nil Entry.find_by(id: entry_id)
  end

  private

    def api_headers(api_key)
      { "X-Api-Key" => api_key.plain_key }
    end
end
