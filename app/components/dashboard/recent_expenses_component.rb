module Dashboard
  class RecentExpensesComponent < BaseWidgetComponent
    def initialize(family:, accounts: nil, limit: 5)
      super(family: family)
      @accounts = accounts || family.accounts
      @limit = limit
    end

    def expenses
      @expenses ||= Entry.visible
                         .excluding_split_parents
                         .where(account_id: @accounts.visible.select(:id), entryable_type: "Transaction", excluded: false)
                         .where("entries.amount > 0")
                         .includes(:account, entryable: :category)
                         .reverse_chronological
                         .limit(@limit)
                         .to_a
    end

    def total_recent_money
      @total_recent_money ||= sum_in_family_currency(expenses) do |entry|
        to_family_money(entry.amount.abs, entry.currency, date: entry.date)
      end
    end

    def category_name(entry)
      entry.entryable&.category&.name || I18n.t("transactions.uncategorized", default: "Sin categoría")
    end
  end
end
