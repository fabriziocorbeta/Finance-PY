module Provider::Openai::Concerns::PygAmount
  extend ActiveSupport::Concern

  AMOUNT_FORMAT_RULE = <<~RULE.strip
    Amounts use Paraguayan Guarani (PYG) format: "." is a THOUSANDS separator, not a decimal point -- PYG has no cents. "295.480" means 295480 (two hundred ninety-five thousand, four hundred eighty), NOT 295.48. Output amounts as plain integers with the dots removed (e.g. 295480), never as a value under 1000 unless the original text is genuinely that small.
  RULE

  private

    # PYG has no cents and uses "." as a thousands separator, so "295.480"
    # is 295480, not 295.48. A naive gsub(/[^0-9.\-]/, "").to_f turned
    # "2.383.271" into 2.383 -- a ~1,000,000x error -- because Ruby's to_f
    # reads a dot as a decimal point regardless of how many appear.
    def parse_amount(amount)
      return nil if amount.nil?
      return amount.to_f if amount.is_a?(Numeric)

      cleaned = amount.to_s.gsub(/[^0-9.,\-]/, "")
      return nil if cleaned.blank?

      negative = cleaned.start_with?("-")
      digits = cleaned.gsub(/[^0-9]/, "")
      return nil if digits.blank?

      value = digits.to_f
      negative ? -value : value
    end
end
