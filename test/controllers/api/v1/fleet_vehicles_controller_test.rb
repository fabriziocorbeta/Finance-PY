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

  test "should show fleet vehicle" do
    get api_v1_fleet_vehicle_url(@vehicle), headers: api_headers(@api_key)
    assert_response :success

    json_response = JSON.parse(response.body)["data"]
    assert_equal @vehicle.id, json_response["id"]
    assert_equal "ABC-123", json_response["plate"]
    assert_equal "Toyota", json_response["brand"]
    assert_equal "Hilux", json_response["model"]
    assert_equal 2022, json_response["year"]
    assert_equal "active", json_response["status"]
  end

  test "should create fleet vehicle" do
    assert_difference -> { FleetVehicle.count } => 1 do
      post api_v1_fleet_vehicles_url,
           params: {
             fleet_vehicle: {
               plate: "DEF-456",
               brand: "Chevrolet",
               model: "S10",
               year: 2023,
               status: "active",
               notes: "Camioneta de trabajo"
             }
           },
           headers: api_headers(@write_api_key)
    end

    assert_response :created
    json_response = JSON.parse(response.body)["data"]
    assert_equal "DEF-456", json_response["plate"]
    assert_equal "Chevrolet", json_response["brand"]
  end

  test "should return unprocessable entity on invalid create" do
    post api_v1_fleet_vehicles_url,
         params: {
           fleet_vehicle: {
             plate: "",
             brand: "Chevrolet"
           }
         },
         headers: api_headers(@write_api_key)

    assert_response :unprocessable_entity
  end

  test "should update fleet vehicle" do
    patch api_v1_fleet_vehicle_url(@vehicle),
          params: {
            fleet_vehicle: {
              status: "maintenance",
              notes: "En taller por mantenimiento"
            }
          },
          headers: api_headers(@write_api_key)

    assert_response :success
    @vehicle.reload
    assert_equal "maintenance", @vehicle.status
    assert_equal "En taller por mantenimiento", @vehicle.notes
  end

  test "should destroy fleet vehicle" do
    assert_difference -> { FleetVehicle.count } => -1 do
      delete api_v1_fleet_vehicle_url(@vehicle), headers: api_headers(@write_api_key)
    end

    assert_response :success
  end

  test "should not destroy another family's vehicle" do
    other_family = Family.create!(name: "Other Family", currency: "USD", locale: "en")
    other_vehicle = FleetVehicle.create!(
      family: other_family,
      plate: "XYZ-999",
      brand: "Ford",
      model: "Ranger",
      year: 2021
    )

    assert_no_difference -> { FleetVehicle.count } do
      delete api_v1_fleet_vehicle_url(other_vehicle), headers: api_headers(@write_api_key)
    end

    assert_response :not_found
  end

  private

    def api_headers(api_key)
      { "X-Api-Key" => api_key.plain_key }
    end
end
