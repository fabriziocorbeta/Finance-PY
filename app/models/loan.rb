class Loan < ApplicationRecord
  include Accountable

  # See CreditCard's belongs_to :family comment.
  belongs_to :family, optional: true

  SUBTYPES = {
    "mortgage" => { short: "Mortgage", long: "Mortgage" },
    "student" => { short: "Student Loan", long: "Student Loan" },
    "auto" => { short: "Auto Loan", long: "Auto Loan" },
    "other" => { short: "Other Loan", long: "Other Loan" }
  }.freeze

  # French: constant total installment, interest share shrinks and principal
  # share grows each period (what monthly_payment computed below, always, for
  # every loan, before this column existed). German: constant principal
  # share (original_balance / term_months), interest charged on the
  # remaining balance -- so the total installment is highest on period 1 and
  # decreases every period after.
  AMORTIZATION_METHODS = %w[french german].freeze

  validates :subtype, inclusion: { in: SUBTYPES.keys }, allow_blank: true
  validates :amortization_method, inclusion: { in: AMORTIZATION_METHODS }, allow_blank: true

  def german_amortization?
    amortization_method == "german"
  end

  # For a French loan this is the (constant) installment. For a German loan
  # there is no single constant installment -- this returns the first and
  # highest one; see #tabs/_overview for the "decreases every period" hint
  # shown alongside it.
  def monthly_payment
    return nil if term_months.nil? || interest_rate.nil? || rate_type.nil? || rate_type != "fixed"
    return Money.new(0, account.currency) if account.loan.original_balance.amount.zero? || term_months.zero?

    german_amortization? ? first_installment_amount : french_monthly_payment
  end

  def original_balance
    Money.new(account.first_valuation_amount, account.currency)
  end

  class << self
    def color
      "#D444F1"
    end

    def icon
      "hand-coins"
    end

    def classification
      "liability"
    end
  end

  private
    def french_monthly_payment
      principal = account.loan.original_balance.amount
      monthly_rate = (interest_rate / 100.0) / 12.0

      payment = if monthly_rate.zero?
        principal / term_months
      else
        (principal * monthly_rate * (1 + monthly_rate)**term_months) / ((1 + monthly_rate)**term_months - 1)
      end

      Money.new(payment.round, account.currency)
    end

    def first_installment_amount
      principal = account.loan.original_balance.amount
      monthly_rate = (interest_rate / 100.0) / 12.0

      principal_share = principal / term_months
      first_interest = principal * monthly_rate

      Money.new((principal_share + first_interest).round, account.currency)
    end
end
