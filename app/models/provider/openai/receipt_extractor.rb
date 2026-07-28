class Provider::Openai::ReceiptExtractor
  attr_reader :client, :image_content, :content_type, :model

  def initialize(client:, image_content:, content_type:, model:)
    @client = client
    @image_content = image_content
    @content_type = content_type
    @model = model
  end

  # Returns the same shape as BankStatementExtractor#extract so that
  # PdfImport#generate_rows_from_extracted_data works unchanged. A receipt
  # is a single purchase, so `transactions` holds zero or one entry.
  def extract
    parsed = request_extraction

    {
      transactions: build_transactions(parsed),
      period: {},
      account_holder: nil,
      account_number: nil,
      bank_name: parsed["merchant"],
      opening_balance: nil,
      closing_balance: nil
    }
  end

  private

    def request_extraction
      response = client.chat(parameters: {
        model: model,
        messages: [
          { role: "system", content: instructions },
          { role: "user", content: [
            { type: "image_url", image_url: { url: "data:#{content_type};base64,#{Base64.strict_encode64(image_content)}", detail: "low" } },
            { type: "text", text: "Extract this receipt and respond with valid JSON only." }
          ] }
        ],
        max_tokens: 500
      })

      parse_json(response.dig("choices", 0, "message", "content"))
    end

    def build_transactions(parsed)
      amount = parse_amount(parsed["amount"] || parsed["total"] || parsed["total_amount"])
      return [] if amount.nil?

      date = parse_date(parsed["date"])
      name = parsed["merchant"].presence || parsed["description"].presence || "Receipt"

      [ {
        date: date,
        amount: -amount.abs,
        name: name,
        category: parsed["category"],
        notes: nil
      } ]
    end

    def parse_json(content)
      return {} if content.blank?

      cleaned = content.to_s.gsub(%r{^```json\s*}i, "").gsub(/```\s*$/, "").strip
      parsed = JSON.parse(cleaned)
      return {} unless parsed.is_a?(Hash)

      # Same stray-leading-character glitch handled in PdfProcessor#normalize_keys
      parsed.transform_keys { |k| k.to_s.sub(/\A[^a-zA-Z0-9]+/, "") }
    rescue JSON::ParserError => e
      Rails.logger.error("ReceiptExtractor JSON parse error: #{e.message}")
      {}
    end

    # Reuses BankStatementExtractor's fixed PYG parsing logic (dot as
    # thousands separator, no cents) instead of duplicating it. `.allocate`
    # avoids needing a full instance (whose `initialize` requires
    # `pdf_content`, which is meaningless here) -- parse_amount doesn't touch
    # any instance state, so an unallocated-but-uninitialized receiver is safe.
    def parse_amount(amount)
      Provider::Openai::BankStatementExtractor
        .allocate
        .send(:parse_amount, amount)
    end

    def parse_date(date_str)
      return Date.current.strftime("%Y-%m-%d") if date_str.blank?

      Date.parse(date_str.to_s).strftime("%Y-%m-%d")
    rescue ArgumentError, TypeError
      Date.current.strftime("%Y-%m-%d")
    end

    def instructions
      <<~INSTRUCTIONS.strip
        You read a photographed purchase receipt (factura) and return its data as JSON.

        Return exactly: {"merchant":"...","date":"YYYY-MM-DD","amount":0}

        Rules:
        - "merchant" is the business name printed on the receipt.
        - "date" is the purchase date, as YYYY-MM-DD.
        - "amount" is the FINAL TOTAL paid (not a subtotal, not a single line item).
        - #{Provider::Openai::BankStatementExtractor::AMOUNT_FORMAT_RULE}
        - JSON only, no markdown, no explanation.
      INSTRUCTIONS
    end
end
