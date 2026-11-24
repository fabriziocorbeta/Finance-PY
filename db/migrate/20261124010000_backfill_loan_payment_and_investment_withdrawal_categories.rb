# frozen_string_literal: true

class BackfillLoanPaymentAndInvestmentWithdrawalCategories < ActiveRecord::Migration[7.2]
  def up
    backfill_category!(
      transaction_where_sql: "transactions.kind = 'loan_payment'",
      locale_names: {
        "en" => "Loan Payments",
        "es" => "Pago de préstamos",
        "ca" => "Pagaments de préstecs",
        "de" => "Kreditzahlungen",
        "fr" => "Remboursements de prêts",
        "nl" => "Leningbetalingen",
        "pl" => "Spłaty pożyczek"
      },
      color: "#e11d48",
      lucide_icon: "credit-card",
      label: "loan_payment"
    )

    backfill_category!(
      transaction_where_sql: "transactions.kind = 'investment_contribution' AND transactions.investment_activity_label = 'Withdrawal'",
      locale_names: {
        "en" => "Investment Withdrawals",
        "es" => "Retiro de inversiones",
        "ca" => "Retirades d'inversió",
        "de" => "Anlageentnahmen",
        "fr" => "Retraits d'investissements",
        "nl" => "Investeringsopnames",
        "pl" => "Wypłaty inwestycyjne"
      },
      color: "#f59e0b",
      lucide_icon: "trending-down",
      label: "investment_withdrawal"
    )
  end

  def down
    # No-op: cannot distinguish backfilled records from user-assigned categories.
  end

  private
    def backfill_category!(transaction_where_sql:, locale_names:, color:, lucide_icon:, label:)
      quoted_names = locale_names.values.uniq.map { |n| connection.quote(n) }.join(", ")

      # Ensure affected families have the target category in their own locale
      case_locale_sql = locale_names.map do |loc, name|
        "WHEN f.locale = #{connection.quote(loc)} THEN #{connection.quote(name)}"
      end.join(" ")
      default_name = connection.quote(locale_names.fetch("en"))

      say_with_time "Ensuring #{label} category exists for affected families" do
        execute <<-SQL.squish
          INSERT INTO categories (id, family_id, name, color, lucide_icon, created_at, updated_at)
          SELECT DISTINCT
            gen_random_uuid(),
            f.id,
            CASE #{case_locale_sql} ELSE #{default_name} END,
            #{connection.quote(color)},
            #{connection.quote(lucide_icon)},
            NOW(),
            NOW()
          FROM families f
          JOIN accounts a ON a.family_id = f.id
          JOIN entries e ON e.account_id = a.id AND e.entryable_type = 'Transaction'
          JOIN transactions ON transactions.id = e.entryable_id
          WHERE #{transaction_where_sql}
            AND transactions.category_id IS NULL
            AND NOT EXISTS (
              SELECT 1 FROM categories c
              WHERE c.family_id = f.id
                AND c.name IN (#{quoted_names})
            )
        SQL
      end

      say_with_time "Backfilling category for #{label} transactions" do
        execute <<-SQL.squish
          UPDATE transactions
          SET category_id = matched_category.id
          FROM entries, accounts,
            LATERAL (
              SELECT c.id
              FROM categories c
              WHERE c.family_id = accounts.family_id
                AND c.name IN (#{quoted_names})
              ORDER BY c.created_at ASC
              LIMIT 1
            ) AS matched_category
          WHERE #{transaction_where_sql}
            AND transactions.category_id IS NULL
            AND entries.entryable_id = transactions.id
            AND entries.entryable_type = 'Transaction'
            AND accounts.id = entries.account_id
        SQL
      end
    end
end
