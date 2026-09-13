# frozen_string_literal: true

require "test_helper"

class Api::V1::FleetVehiclesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:family_admin)
    @family = @user.family
    @family.update!(business_mode_enabled: true)

    @api_key = ApiKey.create!(
      user: @user,
      name: "Test Read Key",
      scopes: [ "read" ],
      source: "mobile"
    )

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

  test "should list fleet vehicles" do
    get api_v1_fleet_vehicles_url, headers: api_headers(@api_key)
    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response["data"].any? { |v| v["id"] == @vehicle.id }
    assert_equal @family.fleet_vehicles.count, json_response["meta"]["total_count"]
  end

  test "should not list another family's fleet vehicles" do
    other_family = Family.create!(name: "Other Family", currency: "USD", locale: "en")
    other_vehicle = other_family.fleet_vehicles.create!(
      plate: "XYZ-999",
      brand: "Ford",
      model: "Ranger",
      year: 2021,
      status: "active"
    )

    get api_v1_fleet_vehicles_url, headers: api_headers(@api_key)
    assert_response :success

    vehicle_ids = JSON.parse(response.body)["data"].map { |v| v["id"] }
    assert_includes vehicle_ids, @vehicle.id
    assert_not_includes vehicle_ids, other_vehicle.id
  end

  test "should show fleet vehicle detail" do
    get api_v1_fleet_vehicle_url(@vehicle), headers: api_headers(@api_key)
    assert_response :success

    vehicle = JSON.parse(response.body)
    assert_equal @vehicle.id, vehicle["id"]
    assert_equal "ABC-123", vehicle["plate"]
    assert_equal "Toyota", vehicle["brand"]
    assert_equal "Hilux", vehicle["model"]
    assert_equal 2022, vehicle["year"]
    assert_equal "active", vehicle["status"]
    assert_kind_of Hash, vehicle["average_fuel_efficiency"]
    assert_kind_of Hash, vehicle["monthly_fuel_consumed"]
    assert_kind_of Hash, vehicle["monthly_distance"]
    assert_kind_of Array, vehicle["fuel_logs"]
  end

  test "should create fleet vehicle" do
    params = {
      fleet_vehicle: {
        plate: "DEF-456",
        brand: "Nissan",
        model: "Frontier",
        year: 2023,
        status: "active"
      }
    }

    assert_difference -> { @family.fleet_vehicles.count }, 1 do
      post api_v1_fleet_vehicles_url, params: params, headers: api_headers(@write_api_key), as: :json
    end

    assert_response :created
    json_response = JSON.parse(response.body)
    assert_equal "DEF-456", json_response["plate"]
  end

  test "should update fleet vehicle" do
    params = {
      fleet_vehicle: {
        status: "maintenance",
        notes: "Servicio de 10.000km"
      }
    }

    patch api_v1_fleet_vehicle_url(@vehicle), params: params, headers: api_headers(@write_api_key), as: :json
    assert_response :success

    @vehicle.reload
    assert_equal "maintenance", @vehicle.status
    assert_equal "Servicio de 10.000km", @vehicle.notes
  end

  test "should destroy fleet vehicle" do
    assert_difference -> { @family.fleet_vehicles.count }, -1 do
      delete api_v1_fleet_vehicle_url(@vehicle), headers: api_headers(@write_api_key)
    end

    assert_response :no_content
    assert_not FleetVehicle.exists?(@vehicle.id)
  end

  private

    def api_headers(api_key)
      { "X-Api-Key" => api_key.plain_key }
    end
end
