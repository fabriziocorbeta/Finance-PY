class CreditCard < ApplicationRecord
  include Accountable

  # See app/models/concerns/family_id_propagatable.rb: family_id is
  # populated by Account's propagate_family_id_to_accountable callback, not
  # set directly by callers (added in RLS Ola 2 / E1 Etapa B, see
  # db/migrate/20260923143220_add_family_id_to_accountable_and_trade_tables.rb).
  belongs_to :family, optional: true

  SUBTYPES = {
    "credit_card" => { short: "Credit Card", long: "Credit Card" }
  }.freeze

  class << self
    def color
      "#F13636"
    end

    def icon
      "credit-card"
    end

    def classification
      "liability"
    end
  end

  def available_credit_money
    available_credit ? Money.new(available_credit, account.currency) : nil
  end

  def minimum_payment_money
    minimum_payment ? Money.new(minimum_payment, account.currency) : nil
  end

  def annual_fee_money
    annual_fee ? Money.new(annual_fee, account.currency) : nil
  end
end
