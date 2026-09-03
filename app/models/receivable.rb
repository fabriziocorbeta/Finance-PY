class Receivable < ApplicationRecord
  include Accountable

  belongs_to :family

  validates :due_day, inclusion: { in: 1..31 }, allow_nil: true

  def original_balance
    Money.new(account.first_valuation_amount, account.currency)
  end

  class << self
    def color
      "#F79009" # amber -- distinto de todos los colores ya usados por otros Accountable types
      # (Loan #D444F1, CreditCard #F13636, Depository #875BF7, Investment #1570EF,
      #  Crypto/OtherLiability #737373, Property #06AED4, Vehicle #F23E94, OtherAsset #12B76A)
    end

    def icon
      "hand-heart" # distinto de "hand-coins" (Loan)
    end

    def classification
      "asset"
    end
  end
end
