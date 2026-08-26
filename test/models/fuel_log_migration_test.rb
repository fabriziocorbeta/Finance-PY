require "test_helper"

class FuelLogMigrationTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @account = accounts(:other_asset)
    @vehicle = FleetVehicle.create!(
      family: @family,
      plate: "MIG-999",
      brand: "Chevrolet",
      model: "S10"
    )
  end

  test "migration groups split fuel logs sharing vehicle, odometer, and logged_at" do
    logged_date = Date.today - 2.days

    # Create two split fuel logs as was done in legacy behavior, bypassing line creation callbacks
    log1 = FuelLog.new(
      fleet_vehicle: @vehicle,
      account: @account,
      odometer: 45000,
      logged_at: logged_date,
      notes: "Nafta super",
      liters: 15.0,
      cost: 105000
    )
    log1.save!(validate: false)

    log2 = FuelLog.new(
      fleet_vehicle: @vehicle,
      account: @account,
      odometer: 45000,
      logged_at: logged_date,
      notes: "Alcohol carburante",
      liters: 35.0,
      cost: 210000
    )
    log2.save!(validate: false)

    # Create a single log for another date
    log3 = FuelLog.new(
      fleet_vehicle: @vehicle,
      account: @account,
      odometer: 45500,
      logged_at: Date.today,
      notes: "Solo Nafta",
      liters: 50.0,
      cost: 350000
    )
    log3.save!(validate: false)

    # Execute migration logic directly
    require_relative "../../db/migrate/20260819000001_create_fuel_log_lines_and_migrate_historical_data"
    migration = CreateFuelLogLinesAndMigrateHistoricalData.new

    # Run historical migration logic
    migration.send(:migrate_existing_fuel_logs)

    # Check that log1 and log2 were grouped into a single FuelLog
    vehicle_logs = @vehicle.fuel_logs.reload.order(:logged_at)
    assert_equal 2, vehicle_logs.count

    grouped_log = vehicle_logs.find_by(odometer: 45000)
    assert_not_nil grouped_log
    assert_equal 2, grouped_log.fuel_log_lines.count
    assert_equal 50.0, grouped_log.liters
    assert_equal 315000.0, grouped_log.cost
    assert_includes grouped_log.fuel_log_lines.pluck(:fuel_type), "nafta"
    assert_includes grouped_log.fuel_log_lines.pluck(:fuel_type), "alcohol"
  end
end
