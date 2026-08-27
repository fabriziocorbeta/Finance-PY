class FuelLogLine < ApplicationRecord
  belongs_to :fuel_log

  BRANDS_BY_FUEL_TYPE = {
    "nafta" => [ "Podium", "Super 97", "Grid", "Prix" ],
    "diesel" => [ "Podium", "Euro 6", "Euro 5" ]
  }.freeze

  enum :fuel_type, { nafta: "nafta", alcohol: "alcohol", gnc: "gnc", diesel: "diesel" }, default: "nafta"

  validates :fuel_type, presence: true
  validates :liters, presence: true, numericality: { greater_than: 0 }
  validates :cost, presence: true, numericality: { greater_than_or_equal_to: 0 }

  def self.brands_for(fuel_type)
    BRANDS_BY_FUEL_TYPE[fuel_type.to_s] || []
  end
end
