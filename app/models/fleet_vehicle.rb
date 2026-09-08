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

  METRICS = %w[efficiency consumption distance].freeze

  # Builds a Series (same shape used by the account balance chart) of one
  # value per month for the requested metric, oldest to newest, so the
  # existing time-series-chart controller and trend_change partial can be
  # reused as-is instead of writing a second charting stack for fleet data.
  def monthly_metrics_series(metric: "efficiency", months_back: 6)
    months = (months_back - 1).downto(0).map { |n| n.months.ago.to_date.beginning_of_month }

    raw_values = months.map do |month|
      value = case metric
      when "consumption"
        monthly_fuel_consumed(month).values.sum
      when "distance"
        monthly_distance(month).values.sum
      else
        monthly_average_efficiency(month)["overall"] || 0.0
      end

      # .to_f before .round(2): monthly_average_efficiency's "overall" divides
      # a decimal-column liters sum, so it comes back as BigDecimal -- which
      # Rails' default JSON encoder renders as a quoted string ("21.42"), not
      # a number. That's silently wrong for a chart's numeric axis/tooltip.
      { date: month, value: value.to_f.round(2) }
    end

    favorable_direction = metric == "consumption" ? "down" : "up"
    ordered = raw_values.sort_by { |v| v[:date] }

    values = [ nil, *ordered ].each_cons(2).map do |prev_value, curr_value|
      Series::Value.new(
        date: curr_value[:date],
        date_formatted: I18n.l(curr_value[:date], format: :long),
        value: curr_value[:value],
        trend: Trend.new(
          current: curr_value[:value],
          previous: prev_value&.[](:value),
          favorable_direction: favorable_direction
        )
      )
    end

    Series.new(
      start_date: ordered.first[:date],
      end_date: ordered.last[:date],
      interval: "1 month",
      values: values,
      favorable_direction: favorable_direction
    )
  end

  private

    def interval_category(log)
      types = log.fuel_log_lines.map(&:fuel_type).uniq
      types.size == 1 ? types.first : "mixto"
    end
end
