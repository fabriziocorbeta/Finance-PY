module Dashboard
  class AvailableToSpendComponent < BaseWidgetComponent
    LOW_BALANCE_THRESHOLDS = {
      "PYG" => 500_000,
      "USD" => 100
    }.freeze

    def initialize(family:, user: nil, accounts: nil)
      super(family: family)
      @user = user
      @accounts = accounts || family.accounts
    end

    def available_money
      @available_money ||= Rails.cache.fetch(cache_key, expires_in: 15.minutes) do
        liquid_total = sum_in_family_currency(liquid_accounts) { |acc| to_family_money(acc.balance, acc.currency) }
        credit_due   = sum_in_family_currency(credit_accounts) { |acc| to_family_money(acc.balance, acc.currency) }
        liquid_total - credit_due
      end
    end

    def liquid_accounts_count
      liquid_accounts.size
    end

    def low_balance?
      threshold_amount = LOW_BALANCE_THRESHOLDS.fetch(family_currency, 100)
      available_money < Money.new(threshold_amount, family_currency)
    end

    private

      def liquid_accounts
        @liquid_accounts ||= @accounts.visible.where(accountable_type: "Depository").to_a
      end

      def credit_accounts
        @credit_accounts ||= @accounts.visible.where(accountable_type: "CreditCard").to_a
      end

      def cache_key
        [
          "dashboard/widgets/available_to_spend",
          family.id,
          @user&.id,
          family_currency,
          family.accounts_cache_version
        ].join("/")
      end
  end
end
