# frozen_string_literal: true

require "test_helper"

class Api::V1::FuelLogsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:family_admin)
    @family = @user.family
    @family.update!(business_mode_enabled: true)
    @account = accounts(:depository)

    @write_api_key = ApiKey.create!(
      user: @user,
      name: "Test Write Key",
      scopes: [ "read", "write" ],
      source: "mobile"
    )

    @vehicle = @family.fleet_vehicles.create!(
      plate: "ABC-123",
      brand: "Toyota",
      model: "Hilux",
      year: 2022,
      status: "active"
    )
  end

  test "should create fuel_log and automatically create entry and transaction" do
    params = {
      fuel_log: {
        account_id: @account.id,
        logged_at: Date.current.iso8601,
        odometer: 15000,
        notes: "Carga completa",
        fuel_log_lines: [
          { fuel_type: "nafta", brand: "Podium", liters: 40.0, cost: 300000.0 }
        ]
      }
    }

    assert_difference -> { @vehicle.fuel_logs.count } => 1, -> { Entry.count } => 1 do
      post api_v1_fleet_vehicle_fuel_logs_url(@vehicle), params: params, headers: api_headers(@write_api_key), as: :json
    end

    assert_response :created
    json_response = JSON.parse(response.body)
    assert_equal 40.0, json_response["liters"]
    assert_equal 300000.0, json_response["cost"]
    assert_equal 15000, json_response["odometer"]
    assert_equal 1, json_response["fuel_log_lines"].size

    fuel_log = FuelLog.find(json_response["id"])
    assert_not_nil fuel_log.entry
    assert_equal 300000.0, fuel_log.entry.amount.to_f
    assert_equal "Combustible - ABC-123", fuel_log.entry.name
  end

  test "should update fuel_log and update entry" do
    fuel_log = @vehicle.fuel_logs.create!(
      account: @account,
      logged_at: Date.current,
      odometer: 15000,
      fuel_log_lines_attributes: [
        { fuel_type: "nafta", brand: "Podium", liters: 40.0, cost: 300000.0 }
      ]
    )

    params = {
      fuel_log: {
        cost: 350000.0,
        fuel_log_lines: [
          { id: fuel_log.fuel_log_lines.first.id, fuel_type: "nafta", brand: "Podium", liters: 45.0, cost: 350000.0 }
        ]
      }
    }

    patch api_v1_fleet_vehicle_fuel_log_url(@vehicle, fuel_log), params: params, headers: api_headers(@write_api_key), as: :json
    assert_response :success

    fuel_log.reload
    assert_equal 45.0, fuel_log.liters.to_f
    assert_equal 350000.0, fuel_log.cost.to_f
    assert_equal 350000.0, fuel_log.entry.reload.amount.to_f
  end

  test "should destroy fuel_log and destroy associated entry" do
    fuel_log = @vehicle.fuel_logs.create!(
      account: @account,
      logged_at: Date.current,
      odometer: 15000,
      fuel_log_lines_attributes: [
        { fuel_type: "nafta", brand: "Podium", liters: 40.0, cost: 300000.0 }
      ]
    )
    entry_id = fuel_log.entry_id

    assert_difference -> { @vehicle.fuel_logs.count } => -1, -> { Entry.count } => -1 do
      delete api_v1_fleet_vehicle_fuel_log_url(@vehicle, fuel_log), headers: api_headers(@write_api_key)
    end

    assert_response :no_content
    assert_not FuelLog.exists?(fuel_log.id)
    assert_not Entry.exists?(entry_id)
  end

  test "should not create fuel_log for vehicle of another family" do
    other_family = Family.create!(name: "Other Family", currency: "USD", locale: "en")
    other_vehicle = other_family.fleet_vehicles.create!(
      plate: "XYZ-999",
      brand: "Ford",
      model: "Ranger",
      year: 2021,
      status: "active"
    )

    params = {
      fuel_log: {
        account_id: @account.id,
        logged_at: Date.current.iso8601,
        fuel_log_lines: [
          { fuel_type: "nafta", liters: 20.0, cost: 150000.0 }
        ]
      }
    }

    post api_v1_fleet_vehicle_fuel_logs_url(other_vehicle), params: params, headers: api_headers(@write_api_key), as: :json
    assert_response :not_found
  end

  private

    def api_headers(api_key)
      { "X-Api-Key" => api_key.plain_key }
    end
end
