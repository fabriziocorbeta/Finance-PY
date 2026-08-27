require "test_helper"

class FuelLogTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @account = accounts(:other_asset)
    @vehicle = FleetVehicle.create!(
      family: @family,
      plate: "XYZ-123",
      brand: "Toyota",
      model: "Hilux"
    )
    @fuel_log = FuelLog.new(
      fleet_vehicle: @vehicle,
      account: @account,
      odometer: 15000,
      logged_at: Date.today
    )
    @fuel_log.fuel_log_lines.build(fuel_type: "nafta", liters: 50.5, cost: 350000)
  end

  test "should be valid with valid attributes" do
    assert @fuel_log.valid?, @fuel_log.errors.full_messages
  end

  test "should require account" do
    @fuel_log.account = nil
    assert_not @fuel_log.valid?
  end

  test "should require at least one fuel log line" do
    @fuel_log.fuel_log_lines.clear
    assert_not @fuel_log.valid?
  end

  test "liters and cost are automatically synced from fuel log lines" do
    @fuel_log.fuel_log_lines.clear
    @fuel_log.fuel_log_lines.build(fuel_type: "nafta", liters: 10.0, cost: 70000)
    @fuel_log.fuel_log_lines.build(fuel_type: "alcohol", liters: 40.0, cost: 240000)
    @fuel_log.valid?

    assert_equal 50.0, @fuel_log.liters
    assert_equal 310000.0, @fuel_log.cost
  end

  test "odometer must be greater than or equal to 0 if present" do
    @fuel_log.odometer = -1
    assert_not @fuel_log.valid?

    @fuel_log.odometer = 0
    assert @fuel_log.valid?

    @fuel_log.odometer = nil
    assert @fuel_log.valid?
  end

  test "should require logged_at" do
    @fuel_log.logged_at = nil
    assert_not @fuel_log.valid?
  end

  test "account belongs to family" do
    other_family = Family.create!(name: "Other Family", currency: "usd")
    other_account = other_family.accounts.create!(name: "Other Account", currency: "usd", balance: 100, accountable: Depository.new)
    @fuel_log.account = other_account
    assert_not @fuel_log.valid?
  end

  test "should create entry and sync with total cost of multiple lines" do
    @fuel_log.fuel_log_lines.clear
    @fuel_log.fuel_log_lines.build(fuel_type: "nafta", liters: 10.0, cost: 70000)
    @fuel_log.fuel_log_lines.build(fuel_type: "alcohol", liters: 40.0, cost: 240000)

    assert_difference "Entry.count", 1 do
      @fuel_log.save!
    end
    assert_equal 310000, @fuel_log.entry.amount
  end

  test "associated entry is categorized as Combustible" do
    @fuel_log.save!
    assert_equal "Combustible", @fuel_log.entry.transaction.category.name
  end
end
