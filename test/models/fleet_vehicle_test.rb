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

  test "can save optional brand on fuel log line" do
    log = @vehicle.fuel_logs.create!(
      account: @account,
      odometer: 10000,
      logged_at: Date.today,
      fuel_log_lines_attributes: [
        { fuel_type: "nafta", brand: "Podium", liters: 40, cost: 280000 }
      ]
    )

    line = log.fuel_log_lines.first
    assert_equal "Podium", line.brand
  end

  test "average_fuel_efficiency separates single fuel type, mixed fill-ups, and prevents contamination between categories" do
    # Log 0: Initial fill up at 10,000 km
    @vehicle.fuel_logs.create!(
      account: @account,
      odometer: 10000,
      logged_at: 10.days.ago,
      fuel_log_lines_attributes: [
        { fuel_type: "nafta", brand: "Super 97", liters: 40, cost: 280000 }
      ]
    )

    # Log 1: Single fuel type (Nafta) at 10,500 km (distance 500 km, 50L) -> 10.0 km/L Nafta
    @vehicle.fuel_logs.create!(
      account: @account,
      odometer: 10500,
      logged_at: 8.days.ago,
      fuel_log_lines_attributes: [
        { fuel_type: "nafta", brand: "Grid", liters: 50, cost: 350000 }
      ]
    )

    # Log 2: Single fuel type (Alcohol) at 11,000 km (distance 500 km, 50L) -> 10.0 km/L Alcohol
    @vehicle.fuel_logs.create!(
      account: @account,
      odometer: 11000,
      logged_at: 6.days.ago,
      fuel_log_lines_attributes: [
        { fuel_type: "alcohol", liters: 50, cost: 300000 }
      ]
    )

    # Log 3: Mixed fuel fill-up (Nafta + Alcohol) at 11,400 km (distance 400 km, 10L nafta + 40L alcohol = 50L total) -> 8.0 km/L Mixto
    @vehicle.fuel_logs.create!(
      account: @account,
      odometer: 11400,
      logged_at: 4.days.ago,
      fuel_log_lines_attributes: [
        { fuel_type: "nafta", brand: "Prix", liters: 10, cost: 70000 },
        { fuel_type: "alcohol", liters: 40, cost: 240000 }
      ]
    )

    # Log 4: Single fuel type (Nafta) at 12,000 km (distance 600 km, 50L) -> 12.0 km/L Nafta
    @vehicle.fuel_logs.create!(
      account: @account,
      odometer: 12000,
      logged_at: Date.today,
      fuel_log_lines_attributes: [
        { fuel_type: "nafta", brand: "Podium", liters: 50, cost: 400000 }
      ]
    )

    efficiency = @vehicle.average_fuel_efficiency

    # Nafta average: (10.0 + 12.0) / 2 = 11.0
    assert_equal 11.0, efficiency["nafta"]

    # Alcohol average: 10.0
    assert_equal 10.0, efficiency["alcohol"]

    # Mixto average: 8.0
    assert_equal 8.0, efficiency["mixto"]
  end

  test "monthly_fuel_consumed, monthly_distance, and monthly_average_efficiency" do
    current_month = Date.current

    # Last log of previous month at 10,000 km
    @vehicle.fuel_logs.create!(
      account: @account,
      odometer: 10000,
      logged_at: current_month.prev_month.end_of_month,
      fuel_log_lines_attributes: [
        { fuel_type: "nafta", brand: "Super 97", liters: 50, cost: 350000 }
      ]
    )

    # First log of current month at 10,400 km with 20L nafta + 20L alcohol (40L total, mixed) -> 400 km / 40 L = 10 km/L Mixto
    @vehicle.fuel_logs.create!(
      account: @account,
      odometer: 10400,
      logged_at: current_month.beginning_of_month + 2.days,
      fuel_log_lines_attributes: [
        { fuel_type: "nafta", brand: "Grid", liters: 20, cost: 140000 },
        { fuel_type: "alcohol", liters: 20, cost: 120000 }
      ]
    )

    # Second log of current month at 11,000 km with 60L nafta (single) -> 600 km / 60 L = 10 km/L Nafta
    @vehicle.fuel_logs.create!(
      account: @account,
      odometer: 11000,
      logged_at: current_month.beginning_of_month + 10.days,
      fuel_log_lines_attributes: [
        { fuel_type: "nafta", brand: "Podium", liters: 60, cost: 420000 }
      ]
    )

    # Monthly consumed by fuel type: nafta: 20 + 60 = 80L, alcohol: 20L
    consumed = @vehicle.monthly_fuel_consumed(current_month)
    assert_equal 80.0, consumed["nafta"]
    assert_equal 20.0, consumed["alcohol"]

    # Monthly distance by interval category: mixto: 400 km, nafta: 600 km
    distance = @vehicle.monthly_distance(current_month)
    assert_equal 400.0, distance["mixto"]
    assert_equal 600.0, distance["nafta"]
    assert_equal 1000.0, distance.values.sum

    # Monthly efficiency by interval category: mixto: 10.0, nafta: 10.0
    efficiency = @vehicle.monthly_average_efficiency(current_month)
    assert_equal 10.0, efficiency["mixto"]
    assert_equal 10.0, efficiency["nafta"]
  end

  test "monthly_metrics_series builds one point per month, oldest to newest, with real trends" do
    current_month = Date.current

    @vehicle.fuel_logs.create!(
      account: @account,
      odometer: 10000,
      logged_at: current_month.prev_month.end_of_month,
      fuel_log_lines_attributes: [
        { fuel_type: "nafta", liters: 50, cost: 350000 }
      ]
    )

    @vehicle.fuel_logs.create!(
      account: @account,
      odometer: 11000,
      logged_at: current_month.beginning_of_month + 10.days,
      fuel_log_lines_attributes: [
        { fuel_type: "nafta", liters: 60, cost: 420000 }
      ]
    )

    series = @vehicle.monthly_metrics_series(metric: "efficiency", months_back: 3)

    assert_equal 3, series.values.size
    assert_equal current_month.beginning_of_month, series.values.last.date
    # 1000 km / 60 L = 16.67 km/L for the current month, 0 for the two empty months before it
    assert_equal 0.0, series.values.first.value
    assert_in_delta 16.67, series.values.last.value, 0.01

    distance_series = @vehicle.monthly_metrics_series(metric: "distance", months_back: 3)
    assert_equal 1000.0, distance_series.values.last.value

    consumption_series = @vehicle.monthly_metrics_series(metric: "consumption", months_back: 3)
    assert_equal 60.0, consumption_series.values.last.value

    # Consumption is unfavorable when it goes up -- direction "up" should read as unfavorable, not a win.
    assert_equal "down", consumption_series.favorable_direction
    assert_equal "up", distance_series.favorable_direction
  end
end
