class AddAmortizationMethodToLoans < ActiveRecord::Migration[7.2]
  def change
    # Loan#monthly_payment only ever implemented the French system (constant
    # total installment, decreasing interest / increasing principal share) --
    # there was no column or UI control for it at all, so a loan actually
    # paid under the German system (constant principal share, decreasing
    # total installment) had no way to be represented correctly. Default to
    # "french" so every existing loan keeps computing exactly as before.
    add_column :loans, :amortization_method, :string, default: "french", null: false
  end
end
