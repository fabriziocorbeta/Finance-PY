class FleetVehicle < ApplicationRecord
  belongs_to :family
  has_many :fuel_logs, foreign_key: :fleet_vehicle_id, dependent: :destroy

  enum :status, { active: "active", maintenance: "maintenance", inactive: "inactive" }, default: "active"

  validates :plate, presence: true, uniqueness: { scope: :family_id }
  validates :brand, presence: true
  validates :model, presence: true

  def average_fuel_efficiency
    logs = fuel_logs.includes(:fuel_log_lines).where.not(odometer: nil).order(:logged_at, :created_at)
    return {} if logs.size < 2

    category_efficiencies = Hash.new { |h, k| h[k] = [] }
    total_distance = 0.0
    total_liters = 0.0

    logs.each_cons(2) do |prev_log, curr_log|
      distance = curr_log.odometer - prev_log.odometer
      liters = curr_log.fuel_log_lines.sum(&:liters)

      next unless distance > 0 && liters > 0

      category = interval_category(curr_log)
      category_efficiencies[category] << (distance.to_f / liters)
      total_distance += distance
      total_liters += liters
    end

    return {} if category_efficiencies.empty?

    result = category_efficiencies.transform_values do |effs|
      effs.sum / effs.size
    end

    result["overall"] = total_distance / total_liters if total_liters > 0
    result
  end

  def monthly_fuel_consumed(month = Date.current)
    start_date = month.beginning_of_month
    end_date = month.end_of_month

    month_logs = fuel_logs.includes(:fuel_log_lines).where(logged_at: start_date..end_date)

    consumed_by_type = Hash.new(0.0)
    month_logs.each do |log|
      log.fuel_log_lines.each do |line|
        consumed_by_type[line.fuel_type] += line.liters.to_f
      end
    end

    consumed_by_type.reject { |_, v| v <= 0 }
  end

  def monthly_distance(month = Date.current)
    start_date = month.beginning_of_month
    end_date = month.end_of_month

    month_logs = fuel_logs.includes(:fuel_log_lines).where.not(odometer: nil).where(logged_at: start_date..end_date).order(:logged_at, :created_at)
    return {} if month_logs.empty?

    first_log = month_logs.first
    prev_log = fuel_logs.where.not(odometer: nil).where("logged_at < ? OR (logged_at = ? AND created_at < ?)", start_date, first_log.logged_at, first_log.created_at).order(:logged_at, :created_at).last

    all_logs = ([ prev_log ].compact + month_logs.to_a).uniq

    category_distances = Hash.new(0.0)

    all_logs.each_cons(2) do |prev, curr|
      next unless month_logs.include?(curr)

      distance = curr.odometer - prev.odometer
      next unless distance > 0

      category = interval_category(curr)
      category_distances[category] += distance.to_f
    end

    category_distances.reject { |_, v| v <= 0 }
  end

  def monthly_average_efficiency(month = Date.current)
    start_date = month.beginning_of_month
    end_date = month.end_of_month

    month_logs = fuel_logs.includes(:fuel_log_lines).where.not(odometer: nil).where(logged_at: start_date..end_date).order(:logged_at, :created_at)
    return {} if month_logs.empty?

    first_log = month_logs.first
    prev_log = fuel_logs.where.not(odometer: nil).where("logged_at < ? OR (logged_at = ? AND created_at < ?)", start_date, first_log.logged_at, first_log.created_at).order(:logged_at, :created_at).last

    all_logs = ([ prev_log ].compact + month_logs.to_a).uniq

    category_efficiencies = Hash.new { |h, k| h[k] = [] }
    total_distance = 0.0
    total_liters = 0.0

    all_logs.each_cons(2) do |prev, curr|
      next unless month_logs.include?(curr)

      distance = curr.odometer - prev.odometer
      liters = curr.fuel_log_lines.sum(&:liters)
      next unless distance > 0 && liters > 0

      category = interval_category(curr)
      category_efficiencies[category] << (distance.to_f / liters)
      total_distance += distance
      total_liters += liters
    end

    return {} if category_efficiencies.empty?

    result = category_efficiencies.transform_values do |effs|
      effs.sum / effs.size
    end

    result["overall"] = total_distance / total_liters if total_liters > 0
    result
  end

  private

    def interval_category(log)
      types = log.fuel_log_lines.map(&:fuel_type).uniq
      types.size == 1 ? types.first : "mixto"
    end
end
