module StatementParser
  class ParsedTransaction
    attr_reader :date, :description, :amount_cents, :currency, :transaction_type, :balance_cents

    def initialize(attrs)
      data = attrs.is_a?(Hash) ? attrs.transform_keys(&:to_sym) : attrs.to_h
      @date             = parse_date(data[:date])
      @description      = data[:description].to_s.strip
      @amount_cents     = data[:amount_cents].to_i
      @currency         = parse_currency(data[:currency])
      @transaction_type = data[:transaction_type]&.to_sym || :unknown
      @balance_cents    = data[:balance_cents]&.to_i
    end

    def debit?  = transaction_type == :debit
    def credit? = transaction_type == :credit

    # A row is safe to import only when it has a real date and a currency
    # code the app actually understands. Rows failing this (malformed AI
    # output, a currency the Money gem doesn't recognize) are skipped rather
    # than silently stored with garbage/nil values -- see
    # StatementImportsController#confirm.
    def valid?
      date.present? && currency.present?
    end

    def to_h
      {
        date:             date&.iso8601,
        description:      description,
        amount_cents:     amount_cents,
        currency:         currency,
        transaction_type: transaction_type.to_s,
        balance_cents:    balance_cents
      }
    end

    private

      def parse_date(value)
        return nil if value.nil?
        value.is_a?(Date) ? value : Date.parse(value.to_s)
      rescue ArgumentError, TypeError
        nil
      end

      # Normalizes to an uppercase 3-letter code and validates it against the
      # Money gem's known currencies (same pattern as
      # CurrencyNormalizable#parse_currency / Import::Row#currency), so a
      # hallucinated or malformed currency ("Guaranies", "XXX", nil) becomes
      # nil instead of silently flowing into Entry#currency.
      def parse_currency(value)
        code = value.presence&.to_s&.strip&.upcase || "PYG"
        return nil unless code.match?(/\A[A-Z]{3}\z/)
        Money::Currency.new(code)
        code
      rescue Money::Currency::UnknownCurrencyError
        nil
      end
  end
end
