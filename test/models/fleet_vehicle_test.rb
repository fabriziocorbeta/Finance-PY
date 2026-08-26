require "test_helper"

class FleetVehicleTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @account = accounts(:other_asset)
    @vehicle = FleetVehicle.create!(
      family: @family,
      plate: "XYZ-123",
      brand: "Toyota",
      model: "Hilux"
    )
  end

  test "should be valid with valid attributes" do
    assert @vehicle.valid?
  end

  test "should require plate" do
    @vehicle.plate = nil
    assert_not @vehicle.valid?
    assert_includes @vehicle.errors[:plate], "can't be blank"
  end

  test "should require brand" do
    @vehicle.brand = nil
    assert_not @vehicle.valid?
    assert_includes @vehicle.errors[:brand], "can't be blank"
  end

  test "should require model" do
    @vehicle.model = nil
    assert_not @vehicle.valid?
    assert_includes @vehicle.errors[:model], "can't be blank"
  end

  test "plate should be unique within family" do
    duplicate_vehicle = FleetVehicle.new(
      family: @family,
      plate: "XYZ-123",
      brand: "Honda",
      model: "Civic"
    )
    assert_not duplicate_vehicle.valid?
    assert_includes duplicate_vehicle.errors[:plate], "has already been taken"
  end

  test "plate can be duplicated across different families" do
    other_family = Family.create!(name: "Other Family", currency: "pyg")

    other_vehicle = FleetVehicle.new(
      family: other_family,
      plate: "XYZ-123",
      brand: "Honda",
      model: "Civic"
    )
    assert other_vehicle.valid?
  end

  test "average_fuel_efficiency calculates correctly for multi-fuel fill-up events" do
    # Log 1: Initial fill up at 10,000 km
    log1 = @vehicle.fuel_logs.create!(
      account: @account,
      odometer: 10000,
      logged_at: 10.days.ago,
      fuel_log_lines_attributes: [
        { fuel_type: "nafta", liters: 40, cost: 280000 }
      ]
    )

    # Log 2: Fill up at 10,500 km (distance 500 km) with mixed fuel (10L nafta + 40L alcohol = 50L total)
    # Expected efficiency: 500 km / 50 L = 10 km/L
    log2 = @vehicle.fuel_logs.create!(
      account: @account,
      odometer: 10500,
      logged_at: 5.days.ago,
      fuel_log_lines_attributes: [
        { fuel_type: "nafta", liters: 10, cost: 70000 },
        { fuel_type: "alcohol", liters: 40, cost: 240000 }
      ]
    )

    # Log 3: Fill up at 11,000 km (distance 500 km) with 50L nafta
    # Expected efficiency: 500 km / 50 L = 10 km/L
    log3 = @vehicle.fuel_logs.create!(
      account: @account,
      odometer: 11000,
      logged_at: Date.today,
      fuel_log_lines_attributes: [
        { fuel_type: "nafta", liters: 50, cost: 350000 }
      ]
    )

    # Average efficiency should be (10 + 10) / 2 = 10.0
    assert_equal 10.0, @vehicle.average_fuel_efficiency
  end
end
