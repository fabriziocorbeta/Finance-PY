# frozen_string_literal: true

require "test_helper"

class Api::V1::FleetVehiclesControllerTest < ActionDispatch::IntegrationTest
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
      year: 2022,
      status: "active"
    )
  end

  test "should list fleet vehicles" do
    get api_v1_fleet_vehicles_url, headers: api_headers(@api_key)
    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response["data"].any? { |v| v["id"] == @vehicle.id }
  end

  test "should not list another family's fleet vehicles" do
    other_family = Family.create!(name: "Other Family", currency: "USD", locale: "en")
    other_vehicle = FleetVehicle.create!(
      family: other_family,
      plate: "XYZ-999",
      brand: "Ford",
      model: "Ranger",
      year: 2021
    )

    get api_v1_fleet_vehicles_url, headers: api_headers(@api_key)
    assert_response :success

    ids = JSON.parse(response.body)["data"].map { |v| v["id"] }
    assert_includes ids, @vehicle.id
    assert_not_includes ids, other_vehicle.id
  end

  test "should require authentication when listing fleet vehicles" do
    get api_v1_fleet_vehicles_url
    assert_response :unauthorized
  end

  test "should require read scope when listing fleet vehicles" do
    api_key_without_read = api_key_without_read_scope
    get api_v1_fleet_vehicles_url, headers: api_headers(api_key_without_read)
    assert_response :forbidden
  ensure
    api_key_without_read&.destroy
  end

  test "should show fleet vehicle" do
    get api_v1_fleet_vehicle_url(@vehicle), headers: api_headers(@api_key)
    assert_response :success

    vehicle_data = JSON.parse(response.body)["data"]
    assert_equal @vehicle.id, vehicle_data["id"]
    assert_equal "ABC-123", vehicle_data["plate"]
    assert_equal "Toyota", vehicle_data["brand"]
    assert_equal "Hilux", vehicle_data["model"]
    assert_equal 2022, vehicle_data["year"]
    assert_equal "active", vehicle_data["status"]
  end

  test "should not show another family's fleet vehicle" do
    other_family = Family.create!(name: "Other Family", currency: "USD", locale: "en")
    other_vehicle = FleetVehicle.create!(
      family: other_family,
      plate: "XYZ-999",
      brand: "Ford",
      model: "Ranger"
    )

    get api_v1_fleet_vehicle_url(other_vehicle), headers: api_headers(@api_key)
    assert_response :not_found
  end

  test "should create fleet vehicle" do
    assert_difference "FleetVehicle.count", 1 do
      post api_v1_fleet_vehicles_url,
           params: {
             fleet_vehicle: {
               plate: "DEF-456",
               brand: "Nissan",
               model: "Frontier",
               year: 2023,
               status: "active"
             }
           },
           headers: api_headers(@write_api_key)
    end

    assert_response :created
    json_response = JSON.parse(response.body)["data"]
    assert_equal "DEF-456", json_response["plate"]
    assert_equal "Nissan", json_response["brand"]
  end

  test "should require write scope when creating fleet vehicle" do
    post api_v1_fleet_vehicles_url,
         params: { fleet_vehicle: { plate: "FFF-000", brand: "Test", model: "Car" } },
         headers: api_headers(@api_key)

    assert_response :forbidden
  end

  test "should return unprocessable entity on invalid vehicle create" do
    post api_v1_fleet_vehicles_url,
         params: { fleet_vehicle: { plate: "" } },
         headers: api_headers(@write_api_key)

    assert_response :unprocessable_entity
  end

  test "should update fleet vehicle" do
    patch api_v1_fleet_vehicle_url(@vehicle),
          params: { fleet_vehicle: { brand: "Toyota Updated", status: "maintenance" } },
          headers: api_headers(@write_api_key)

    assert_response :success
    json_response = JSON.parse(response.body)["data"]
    assert_equal "Toyota Updated", json_response["brand"]
    assert_equal "maintenance", json_response["status"]

    @vehicle.reload
    assert_equal "Toyota Updated", @vehicle.brand
    assert_equal "maintenance", @vehicle.status
  end

  test "should destroy fleet vehicle" do
    assert_difference "FleetVehicle.count", -1 do
      delete api_v1_fleet_vehicle_url(@vehicle), headers: api_headers(@write_api_key)
    end

    assert_response :success
  end

  private

    def api_key_without_read_scope
      ApiKey.new(
        user: @user,
        name: "No Read Key",
        scopes: [],
        display_key: "test_no_read_#{SecureRandom.hex(8)}",
        source: "mobile"
      ).tap { |api_key| api_key.save!(validate: false) }
    end

    def api_headers(api_key)
      { "X-Api-Key" => api_key.plain_key }
    end
end
