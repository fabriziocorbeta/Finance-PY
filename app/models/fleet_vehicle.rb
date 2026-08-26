class FleetVehicle < ApplicationRecord
  belongs_to :family
  has_many :fuel_logs, foreign_key: :fleet_vehicle_id, dependent: :destroy

  enum :status, { active: "active", maintenance: "maintenance", inactive: "inactive" }, default: "active"

  validates :plate, presence: true, uniqueness: { scope: :family_id }
  validates :brand, presence: true
  validates :model, presence: true

  def average_fuel_efficiency
    logs = fuel_logs.includes(:fuel_log_lines).where.not(odometer: nil).order(:logged_at, :created_at)
    return nil if logs.size < 2

    valid_pairs_efficiencies = []

    logs.each_cons(2) do |prev_log, curr_log|
      distance = curr_log.odometer - prev_log.odometer
      liters = curr_log.fuel_log_lines.sum(&:liters)

      if distance > 0 && liters > 0
        valid_pairs_efficiencies << (distance.to_f / liters)
      end
    end

    return nil if valid_pairs_efficiencies.empty?

    valid_pairs_efficiencies.sum / valid_pairs_efficiencies.size
  end

  def monthly_fuel_consumed(month = Date.current)
    start_date = month.beginning_of_month
    end_date = month.end_of_month

    month_logs = fuel_logs.includes(:fuel_log_lines).where(logged_at: start_date..end_date)
    month_logs.sum { |log| log.fuel_log_lines.sum(&:liters) }
  end

  def monthly_distance(month = Date.current)
    start_date = month.beginning_of_month
    end_date = month.end_of_month

    month_logs = fuel_logs.where.not(odometer: nil).where(logged_at: start_date..end_date).order(:logged_at, :created_at)
    return 0 if month_logs.empty?

    max_odometer = month_logs.last.odometer

    first_log = month_logs.first
    prev_log = fuel_logs.where.not(odometer: nil).where("logged_at < ? OR (logged_at = ? AND created_at < ?)", start_date, first_log.logged_at, first_log.created_at).order(:logged_at, :created_at).last

    start_odometer = prev_log ? prev_log.odometer : month_logs.first.odometer
    distance = max_odometer - start_odometer
    distance > 0 ? distance : 0
  end

  def monthly_average_efficiency(month = Date.current)
    consumed = monthly_fuel_consumed(month)
    dist = monthly_distance(month)

    return nil if consumed <= 0 || dist <= 0

    dist.to_f / consumed
  end
end
