module Dashboard
  class BaseWidgetComponent < ApplicationComponent
    attr_reader :family

    def initialize(family:)
      @family = family
    end

    def family_currency
      @family_currency ||= (family&.currency.presence || "PYG").upcase
    end

    def zero_money
      Money.new(0, family_currency)
    end

    def to_family_money(amount, currency = family_currency, date: Date.current)
      source_currency = (currency.presence || family_currency).to_s.upcase
      money = Money.new(amount || 0, source_currency)
      money.currency.iso_code == family_currency ? money : money.exchange_to(family_currency, date: date)
    rescue Money::ConversionError, ArgumentError, ActiveModel::ValidationError
      zero_money
    end

    def sum_in_family_currency(records)
      records.reduce(zero_money) do |acc, record|
        acc + yield(record)
      end
    end

    def format_money(money)
      (money.is_a?(Money) ? money : Money.new(money || 0, family_currency)).format
    end
  end
end
