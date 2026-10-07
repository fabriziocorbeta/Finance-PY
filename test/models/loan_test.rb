require "test_helper"

class LoanTest < ActiveSupport::TestCase
  test "rejects invalid subtype" do
    loan = Loan.new(subtype: "invalid")

    assert_not loan.valid?
    assert_includes loan.errors[:subtype], "is not included in the list"
  end

  test "calculates correct monthly payment for fixed rate loan" do
    loan_account = Account.create! \
      family: families(:dylan_family),
      name: "Mortgage Loan",
      balance: 500000,
      currency: "USD",
      accountable: Loan.create!(
        family: families(:dylan_family),
        subtype: "mortgage",
        interest_rate: 3.5,
        term_months: 360,
        rate_type: "fixed"
      )

    assert_equal 2245, loan_account.loan.monthly_payment.amount
  end

  test "defaults to french amortization when not set" do
    loan = Loan.new
    assert_not loan.german_amortization?
  end

  test "rejects invalid amortization_method" do
    loan = Loan.new(amortization_method: "invalid")

    assert_not loan.valid?
    assert_includes loan.errors[:amortization_method], "is not included in the list"
  end

  # Sistema alemán: la cuota de capital es fija (principal / plazo) y el
  # interés se calcula sobre el saldo restante, así que la primera cuota es
  # la más alta y decrece cada período -- a diferencia del sistema francés,
  # donde la cuota total es siempre la misma. Con 120.000, 12 meses y 12%
  # anual (1% mensual): cuota de capital = 10.000, interés del primer
  # período = 120.000 * 0.01 = 1.200, primera cuota = 11.200.
  test "calculates the first (highest) installment for a german amortization loan" do
    loan_account = Account.create! \
      family: families(:dylan_family),
      name: "German System Loan",
      balance: 120_000,
      currency: "USD",
      accountable: Loan.create!(
        family: families(:dylan_family),
        subtype: "other",
        interest_rate: 12.0,
        term_months: 12,
        rate_type: "fixed",
        amortization_method: "german"
      )

    assert loan_account.loan.german_amortization?
    assert_equal 11_200, loan_account.loan.monthly_payment.amount
  end
end
