class FuelLogLine < ApplicationRecord
  belongs_to :fuel_log

  enum :fuel_type, { nafta: "nafta", alcohol: "alcohol", gnc: "gnc", diesel: "diesel" }, default: "nafta"

  validates :fuel_type, presence: true
  validates :liters, presence: true, numericality: { greater_than: 0 }
  validates :cost, presence: true, numericality: { greater_than_or_equal_to: 0 }
end
