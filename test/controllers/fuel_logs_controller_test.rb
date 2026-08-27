require "test_helper"

class FuelLogsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @family_admin = users(:family_admin)
    @dylan_family = families(:dylan_family)
    @account = accounts(:other_asset)

    @dylan_family.update!(business_mode_enabled: true)

    sign_in @family_admin

    @fleet_vehicle = @dylan_family.fleet_vehicles.create!(
      plate: "AAA-123",
      brand: "Toyota",
      model: "Hilux"
    )

    @fuel_log = @fleet_vehicle.fuel_logs.create!(
      account: @account,
      logged_at: Date.current,
      fuel_log_lines_attributes: [
        { fuel_type: "nafta", brand: "Podium", liters: 50.5, cost: 150000 }
      ]
    )
  end

  test "should create fuel log with multiple lines and brands" do
    assert_difference("FuelLog.count", 1) do
      assert_difference("FuelLogLine.count", 2) do
        post fleet_vehicle_fuel_logs_url(@fleet_vehicle), params: {
          fuel_log: {
            account_id: @account.id,
            odometer: 12000,
            logged_at: Date.current,
            notes: "Carga mixta",
            fuel_log_lines_attributes: {
              "0" => { fuel_type: "nafta", brand: "Super 97", liters: "10.0", cost: "70000" },
              "1" => { fuel_type: "alcohol", brand: "", liters: "40.0", cost: "240000" }
            }
          }
        }
      end
    end

    created_log = @fleet_vehicle.fuel_logs.order(:created_at).last
    assert_equal 50.0, created_log.liters
    assert_equal 310000.0, created_log.cost

    # order(:id) sorts by gen_random_uuid(), not insertion order - flaky ~50% of runs.
    # Look up each line by fuel_type instead of relying on row order.
    nafta_line = created_log.fuel_log_lines.find_by!(fuel_type: "nafta")
    alcohol_line = created_log.fuel_log_lines.find_by!(fuel_type: "alcohol")
    assert_equal "Super 97", nafta_line.brand
    assert_nil alcohol_line.brand.presence

    assert_redirected_to fleet_vehicle_url(@fleet_vehicle)
  end

  test "should destroy fuel log" do
    assert_difference("FuelLog.count", -1) do
      delete fleet_vehicle_fuel_log_url(@fleet_vehicle, @fuel_log)
    end

    assert_redirected_to fleet_vehicle_url(@fleet_vehicle)
  end

  test "redirects when business mode is disabled" do
    @dylan_family.update!(business_mode_enabled: false)

    post fleet_vehicle_fuel_logs_url(@fleet_vehicle), params: {
      fuel_log: {
        account_id: @account.id,
        logged_at: Date.current,
        fuel_log_lines_attributes: {
          "0" => { fuel_type: "nafta", liters: "45.0", cost: "135000" }
        }
      }
    }
    assert_redirected_to root_url
  end
end
