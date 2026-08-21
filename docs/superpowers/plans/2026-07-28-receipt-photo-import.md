# Receipt/Factura Photo Import Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a photographed receipt/factura (jpg/png) go through the existing "Importar documento" flow and come out as a reviewable pending transaction, instead of silently landing in the dead vector-store upload path it hits today.

**Architecture:** Reuses the entire existing `PdfImport` → `ProcessPdfJob` → classify → extract → `Import::Row` pipeline unchanged. Four things are added: a `receipt` document type, content-type awareness in `PdfProcessor` (so an image skips `PDF::Reader` and `pdftoppm` and goes straight to a vision model), a small `ReceiptExtractor` that returns the same `{transactions: [...]}` shape `BankStatementExtractor` already returns (so `generate_rows_from_extracted_data` needs no changes at all), and an extension check in the controller that routes images to `create_pdf_import`.

**Tech Stack:** Ruby on Rails 7.2, Minitest, NVIDIA NIM (OpenAI-compatible endpoint), Active Storage.

## Global Constraints

- **Vision model is `nvidia/nemotron-nano-12b-v2-vl`.** Verified live this session against a real financial-document image (4.7s, correctly read the statement total). Do NOT substitute another model: `nvidia/llama-3.2-90b-vision-instruct` and `google/gemma-3-12b-it` both return **404** on this account, and the current text-extraction model (`openai/gpt-oss-20b`) is not vision-capable.
- **PYG amount format:** "." is a THOUSANDS separator, not a decimal point — PYG has no cents. `"295.480"` means `295480`. The existing `AMOUNT_FORMAT_RULE` constant in `BankStatementExtractor` states this; reuse it, do not duplicate the string.
- **Tests run via the isolated test-runner only.** Never `bin/rails test` against the `web`/`worker` services (they share the production Supabase database). Use:
  `docker compose -f compose.prod.yml --profile test up -d test-db` (once), then
  `docker compose -f compose.prod.yml --profile test run --rm --build test-runner bin/rails test <path>`.
  **Never run a bare `docker compose --profile test down`** — it tears down the whole production stack (it did, for real, on 2026-07-28).
- Local Ruby is 2.6.6 and cannot run this suite (needs 3.4.7). All test runs go through the VM's test-runner as above. `ruby -c` for syntax checking locally is fine.
- Scope: one photo = one transaction (merchant + date + total). No itemized line-splitting.

## Resolutions for the spec's two open items

The spec (`docs/superpowers/specs/2026-07-28-receipt-photo-import-design.md`) deferred two decisions to planning time. Both are now settled:

1. **Reuse one vision call for classification + extraction, or accept two?** → **Two calls.** Threading a single call's result through `process_with_ai` and `extract_transactions` would mean restructuring both methods and the job that sequences them, for one image. The two calls are ~5s each on the verified vision model. Not worth the coupling.
2. **Rename `BANK_STATEMENT_MODEL`/`BANK_STATEMENT_REQUEST_TIMEOUT` now that a second extractor uses them?** → **No rename.** Receipts need a *different* model (vision, not text), so they get their own `VISION_MODEL` constant rather than sharing the bank-statement one — the name stays accurate for its one caller. Receipts do reuse `bank_statement_client` (the 180s-timeout HTTP client), which is a timeout concern, not a bank-statement concern; renaming that alone is churn without benefit.

---

## Task 1: `receipt` document type plumbing

Adds the new document type end to end through classification and the two independent `statement_with_transactions?` checks, with no AI involved yet. After this task a document manually marked `receipt` is *eligible* for transaction extraction; nothing produces that classification yet.

**Files:**
- Modify: `app/models/import.rb:10` (the `DOCUMENT_TYPES` constant)
- Modify: `app/models/pdf_import.rb:94-96` (`PdfImport#statement_with_transactions?`)
- Modify: `app/jobs/process_pdf_job.rb:85-87` (`ProcessPdfJob#statement_with_transactions?`, a separate private method with the same name and the same list — both must change)
- Modify: `app/models/provider/openai/pdf_processor.rb` (the `instructions` method's document-type list, around line 45-51)
- Modify: `config/locales/views/imports/en.yml` (the `document_types:` block, around line 231)
- Modify: `config/locales/views/imports/es.yml` (the `document_types:` block, around line 168)
- Test: `test/models/pdf_import_test.rb`

**Interfaces:**
- Consumes: nothing from earlier tasks (this is the first).
- Produces: `"receipt"` is a valid member of `Import::DOCUMENT_TYPES`; both `PdfImport#statement_with_transactions?` and `ProcessPdfJob`'s private `statement_with_transactions?(document_type)` return `true` for it. Later tasks rely on a `receipt` classification triggering the extraction branch.

- [ ] **Step 1: Write the failing test**

Add to `test/models/pdf_import_test.rb` (inside the existing class):

```ruby
  test "receipt document type is eligible for transaction extraction" do
    import = PdfImport.new(document_type: "receipt")
    assert import.statement_with_transactions?
  end

  test "receipt is an accepted document type" do
    assert_includes Import::DOCUMENT_TYPES, "receipt"
  end
```

- [ ] **Step 2: Run the test to verify it fails**

Run:
```bash
docker compose -f compose.prod.yml --profile test run --rm --build test-runner bin/rails test test/models/pdf_import_test.rb
```
Expected: FAIL — `"receipt"` is not in `Import::DOCUMENT_TYPES`, and `statement_with_transactions?` returns `false` (`Expected false to be truthy`).

- [ ] **Step 3: Add the document type**

In `app/models/import.rb`, change the `DOCUMENT_TYPES` constant:

```ruby
  DOCUMENT_TYPES = %w[bank_statement credit_card_statement investment_statement receipt financial_document contract other].freeze
```

In `app/models/pdf_import.rb`, change `statement_with_transactions?`:

```ruby
  def statement_with_transactions?
    document_type.in?(%w[bank_statement credit_card_statement receipt])
  end
```

In `app/jobs/process_pdf_job.rb`, change the private method of the same name:

```ruby
    def statement_with_transactions?(document_type)
      document_type.in?(%w[bank_statement credit_card_statement receipt])
    end
```

- [ ] **Step 4: Teach the classifier about the new type**

In `app/models/provider/openai/pdf_processor.rb`, inside the `instructions` method, add a `receipt` bullet immediately before the existing `financial_document` bullet, and narrow `financial_document` so the two don't overlap:

```
         - `receipt`: A single purchase receipt, factura, or invoice for one purchase — one merchant, one date, one total amount. Includes photographed paper receipts.
         - `financial_document`: General financial paperwork that is not a single purchase and not a statement — tax forms, financial reports, payslips.
```

- [ ] **Step 5: Add the display labels**

In `config/locales/views/imports/en.yml`, inside `document_types:`, add after the `investment_statement` line:

```yaml
      receipt: Receipt
```

In `config/locales/views/imports/es.yml`, inside `document_types:`, add after the `investment_statement` line:

```yaml
      receipt: Factura
```

- [ ] **Step 6: Run the test to verify it passes**

Run:
```bash
docker compose -f compose.prod.yml --profile test run --rm --build test-runner bin/rails test test/models/pdf_import_test.rb
```
Expected: PASS, 0 failures.

- [ ] **Step 7: Commit**

```bash
git add app/models/import.rb app/models/pdf_import.rb app/jobs/process_pdf_job.rb app/models/provider/openai/pdf_processor.rb config/locales/views/imports/en.yml config/locales/views/imports/es.yml test/models/pdf_import_test.rb
git commit -m "feat: add receipt document type, eligible for transaction extraction"
```

---

## Task 2: Content-type awareness in `PdfProcessor`

Today `PdfProcessor` assumes its input is always a PDF: it runs `PDF::Reader` first, and its vision fallback shells out to `pdftoppm`. Both fail on a raw JPEG. This task threads the attachment's content type through and branches on it.

**Files:**
- Modify: `app/models/provider/openai.rb` (the `BANK_STATEMENT_MODEL` area for a new constant, and `process_pdf`)
- Modify: `app/models/provider/openai/pdf_processor.rb` (`initialize`, `process`, `process_with_vision`)
- Modify: `app/models/pdf_import.rb` (`process_with_ai`, to pass the content type)
- Test: `test/models/provider/openai/pdf_processor_test.rb`

**Interfaces:**
- Consumes: `Import::DOCUMENT_TYPES` including `"receipt"` from Task 1.
- Produces:
  - `Provider::Openai::VISION_MODEL` — frozen String constant, `ENV.fetch("OPENAI_VISION_MODEL", "nvidia/nemotron-nano-12b-v2-vl")`.
  - `Provider::Openai#process_pdf(pdf_content:, model: "", family: nil, content_type: nil)` — new keyword arg, defaults to `nil` (treated as PDF, so existing callers are unaffected).
  - `Provider::Openai::PdfProcessor.new(client, model:, pdf_content:, custom_provider:, langfuse_trace:, family:, max_response_tokens:, content_type: nil)` — new keyword arg.
  - `PdfProcessor#image_input?` (private) — `true` when `content_type` starts with `"image/"`.

- [ ] **Step 1: Write the failing test**

Create `test/models/provider/openai/pdf_processor_test.rb` if it does not exist; if it does, add these tests to the existing class. Use this full file if creating:

```ruby
require "test_helper"

class Provider::Openai::PdfProcessorTest < ActiveSupport::TestCase
  setup do
    @client = mock("openai_client")
  end

  def build_processor(content_type:, pdf_content: "fake-bytes")
    Provider::Openai::PdfProcessor.new(
      @client,
      model: "test-model",
      pdf_content: pdf_content,
      custom_provider: true,
      langfuse_trace: nil,
      family: nil,
      max_response_tokens: 1000,
      content_type: content_type
    )
  end

  test "treats an image content type as image input" do
    processor = build_processor(content_type: "image/jpeg")
    assert processor.send(:image_input?)
  end

  test "treats a pdf content type as non-image input" do
    processor = build_processor(content_type: "application/pdf")
    assert_not processor.send(:image_input?)
  end

  test "treats a missing content type as non-image input" do
    processor = build_processor(content_type: nil)
    assert_not processor.send(:image_input?)
  end

  test "sends image bytes straight to the vision model without shelling out to pdftoppm" do
    processor = build_processor(content_type: "image/jpeg", pdf_content: "raw-jpeg-bytes")

    # pdftoppm must never be invoked for an image -- it only understands PDFs.
    processor.expects(:convert_pdf_to_images).never
    # PDF::Reader must never see a JPEG either.
    processor.expects(:process_with_text_extraction).never

    captured = nil
    @client.expects(:chat).with { |params| captured = params; true }.returns(
      "choices" => [ { "message" => { "content" => '{"document_type":"receipt","summary":"a receipt"}' } } ]
    )

    processor.process

    image_part = captured[:messages].last[:content].find { |c| c[:type] == "image_url" }
    assert image_part.present?, "expected an image_url part in the vision request"
    assert image_part[:image_url][:url].start_with?("data:image/jpeg;base64,"),
      "expected the real content type in the data URL, got: #{image_part[:image_url][:url][0..40]}"
    assert_equal Provider::Openai::VISION_MODEL, captured[:model]
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

Run:
```bash
docker compose -f compose.prod.yml --profile test run --rm --build test-runner bin/rails test test/models/provider/openai/pdf_processor_test.rb
```
Expected: FAIL — `ArgumentError: unknown keyword: :content_type`.

- [ ] **Step 3: Add the vision model constant**

In `app/models/provider/openai.rb`, immediately after the existing `BANK_STATEMENT_MODEL` constant, add:

```ruby
  # Image inputs (photographed receipts) need a genuinely vision-capable model:
  # BANK_STATEMENT_MODEL (a text model) and the chat model both fail on images.
  # Verified live against a real financial-document image -- the two other
  # vision models on this endpoint (llama-3.2-90b-vision-instruct,
  # gemma-3-12b-it) return 404 on this account, so do not substitute them.
  VISION_MODEL = ENV.fetch("OPENAI_VISION_MODEL", "nvidia/nemotron-nano-12b-v2-vl")
```

- [ ] **Step 4: Thread `content_type` through the provider**

In `app/models/provider/openai.rb`, change the `process_pdf` signature and the `PdfProcessor.new` call inside it:

```ruby
  def process_pdf(pdf_content:, model: "", family: nil, content_type: nil)
```

and in the `PdfProcessor.new(...)` call within that method, add the argument (keep every existing argument exactly as it is):

```ruby
        content_type: content_type
```

- [ ] **Step 5: Make `PdfProcessor` content-type aware**

In `app/models/provider/openai/pdf_processor.rb`:

Add `content_type` to `attr_reader` and `initialize`:

```ruby
  attr_reader :client, :model, :pdf_content, :custom_provider, :langfuse_trace, :family, :max_response_tokens, :content_type

  def initialize(client, model: "", pdf_content: nil, custom_provider: false, langfuse_trace: nil, family: nil, max_response_tokens:, content_type: nil)
    @client = client
    @model = model
    @pdf_content = pdf_content
    @custom_provider = custom_provider
    @langfuse_trace = langfuse_trace
    @family = family
    @max_response_tokens = max_response_tokens
    @content_type = content_type
  end
```

In `process`, skip text extraction entirely for images (a JPEG has no extractable text layer, and `PDF::Reader` on one raises noise before the fallback):

```ruby
    response = if image_input?
      process_with_vision
    else
      begin
        process_with_text_extraction
      rescue Provider::Openai::Error => e
        Rails.logger.warn("Text extraction failed: #{e.message}, trying vision API with images")
        process_with_vision
      end
    end
```

In `process_with_vision`, use the vision model, and build the image parts from the raw bytes when the input is already an image:

```ruby
    def process_with_vision
      effective_model = image_input? ? Provider::Openai::VISION_MODEL : (model.presence || Provider::Openai::DEFAULT_MODEL)

      if image_input?
        images = [ [ Base64.strict_encode64(pdf_content), content_type ] ]
      else
        converted = convert_pdf_to_images
        raise Provider::Openai::Error, "Could not convert PDF to images" if converted.blank?

        # pdftoppm always writes PNG (see convert_pdf_to_images' -png flag)
        images = converted.map { |b64| [ b64, "image/png" ] }
      end

      content = []
      images.first(5).each do |img_base64, img_type|
        content << {
          type: "image_url",
          image_url: {
            url: "data:#{img_type};base64,#{img_base64}",
            detail: "low"
          }
        }
      end
      content << {
        type: "text",
        text: "Please analyze this document (#{images.size} page(s) total, showing first #{[ images.size, 5 ].min}) and respond with valid JSON only."
      }

      # Note: response_format is not compatible with vision, so we ask for JSON in the prompt
      params = {
        model: effective_model,
        messages: [
          { role: "system", content: instructions + "\n\nIMPORTANT: Respond with valid JSON only, no markdown or other formatting." },
          { role: "user", content: content }
        ],
        max_tokens: max_response_tokens
      }

      response = client.chat(parameters: params)

      Rails.logger.info("Tokens used to process document via vision: #{response.dig("usage", "total_tokens")}")

      record_usage(
        effective_model,
        response.dig("usage"),
        operation: "process_pdf_vision",
        metadata: { pdf_size: pdf_content&.bytesize, pages: images.size }
      )

      parse_response_generic(response)
    end
```

Add the predicate to the private section:

```ruby
    def image_input?
      content_type.to_s.start_with?("image/")
    end
```

- [ ] **Step 6: Pass the real content type from `PdfImport`**

In `app/models/pdf_import.rb`, in `process_with_ai`, add the argument to the `provider.process_pdf` call:

```ruby
    response = provider.process_pdf(
      pdf_content: pdf_file_content,
      family: family,
      content_type: pdf_file.content_type
    )
```

- [ ] **Step 7: Run the test to verify it passes**

Run:
```bash
docker compose -f compose.prod.yml --profile test run --rm --build test-runner bin/rails test test/models/provider/openai/pdf_processor_test.rb
```
Expected: PASS, 0 failures.

- [ ] **Step 8: Confirm no PDF regression**

The PDF path shares this code, so re-run the statement extractor and import suites:
```bash
docker compose -f compose.prod.yml --profile test run --rm --build test-runner bin/rails test test/models/provider/openai/bank_statement_extractor_test.rb test/models/pdf_import_test.rb
```
Expected: PASS, 0 failures.

- [ ] **Step 9: Commit**

```bash
git add app/models/provider/openai.rb app/models/provider/openai/pdf_processor.rb app/models/pdf_import.rb test/models/provider/openai/pdf_processor_test.rb
git commit -m "feat: accept image input in PdfProcessor via a vision-capable model"
```

---

## Task 3: `ReceiptExtractor` + PYG-safe amount parsing

Extracts the single transaction from a receipt image. Deliberately not `BankStatementExtractor`: no chunking, no multi-page loop, no retry-on-empty-array (all of which exist to handle a 4-page statement with 45 rows). Returns the same result shape so `PdfImport#generate_rows_from_extracted_data` needs no changes.

**Files:**
- Create: `app/models/provider/openai/receipt_extractor.rb`
- Modify: `app/models/provider/openai.rb` (add `extract_receipt`)
- Modify: `app/models/provider/openai/bank_statement_extractor.rb` (fix `parse_amount` for dot-thousands strings)
- Modify: `app/models/pdf_import.rb` (`extract_transactions` routes by document type)
- Test: `test/models/provider/openai/receipt_extractor_test.rb`
- Test: `test/models/provider/openai/bank_statement_extractor_test.rb` (add the parse_amount regression test)

**Interfaces:**
- Consumes: `Provider::Openai::VISION_MODEL` and the `content_type` plumbing from Task 2; the `receipt` type from Task 1.
- Produces:
  - `Provider::Openai::ReceiptExtractor.new(client:, image_content:, content_type:, model:).extract` → returns `{ transactions: [ { date:, amount:, name:, category:, notes: } ], period: {}, account_holder: nil, account_number: nil, bank_name: nil, opening_balance: nil, closing_balance: nil }` — the same shape `BankStatementExtractor#extract` returns, with exactly zero or one transaction.
  - `Provider::Openai#extract_receipt(image_content:, content_type:, model: "", family: nil)` → wrapped in `with_provider_response` like `extract_bank_statement`.

- [ ] **Step 1: Write the failing tests**

Create `test/models/provider/openai/receipt_extractor_test.rb`:

```ruby
require "test_helper"

class Provider::Openai::ReceiptExtractorTest < ActiveSupport::TestCase
  setup do
    @client = mock("openai_client")
  end

  def build_extractor
    Provider::Openai::ReceiptExtractor.new(
      client: @client,
      image_content: "fake-image-bytes",
      content_type: "image/jpeg",
      model: "test-vision-model"
    )
  end

  def stub_response(content)
    @client.expects(:chat).returns(
      "choices" => [ { "message" => { "content" => content } } ]
    )
  end

  test "extracts a single negative transaction from a receipt" do
    stub_response('{"merchant":"KALON CAFE","date":"2026-07-02","amount":55000}')

    result = build_extractor.extract

    assert_equal 1, result[:transactions].size
    txn = result[:transactions].first
    assert_equal "KALON CAFE", txn[:name]
    assert_equal "2026-07-02", txn[:date]
    assert_equal(-55000.0, txn[:amount])
  end

  test "forces the amount negative even when the model returns a positive number" do
    stub_response('{"merchant":"X","date":"2026-07-02","amount":1000}')

    assert_equal(-1000.0, build_extractor.extract[:transactions].first[:amount])
  end

  test "reads a PYG amount returned as a dot-separated string" do
    stub_response('{"merchant":"X","date":"2026-07-02","amount":"295.480"}')

    assert_equal(-295480.0, build_extractor.extract[:transactions].first[:amount])
  end

  test "returns no transactions when the model returns unusable JSON" do
    stub_response("this is not JSON at all")

    assert_equal [], build_extractor.extract[:transactions]
  end

  test "returns no transactions when the amount is missing" do
    stub_response('{"merchant":"X","date":"2026-07-02"}')

    assert_equal [], build_extractor.extract[:transactions]
  end

  test "sends the image with its real content type to the vision model" do
    captured = nil
    @client.expects(:chat).with { |params| captured = params; true }.returns(
      "choices" => [ { "message" => { "content" => '{"merchant":"X","date":"2026-07-02","amount":1}' } } ]
    )

    build_extractor.extract

    image_part = captured[:messages].last[:content].find { |c| c[:type] == "image_url" }
    assert image_part[:image_url][:url].start_with?("data:image/jpeg;base64,")
  end
end
```

Add to `test/models/provider/openai/bank_statement_extractor_test.rb` (inside the existing class) — this covers a real latent bug, where a dot-separated PYG string was being read as a decimal:

```ruby
  test "parses a PYG amount string with dot thousands separators" do
    extractor = Provider::Openai::BankStatementExtractor.new(
      client: @client, pdf_content: "dummy", model: @model
    )

    assert_equal 295480.0, extractor.send(:parse_amount, "295.480")
    assert_equal(-59096.0, extractor.send(:parse_amount, "-59.096"))
    assert_equal 2383271.0, extractor.send(:parse_amount, "2.383.271")
    assert_equal 1500.0, extractor.send(:parse_amount, 1500)
    assert_equal(-1500.0, extractor.send(:parse_amount, -1500))
  end
```

- [ ] **Step 2: Run the tests to verify they fail**

Run:
```bash
docker compose -f compose.prod.yml --profile test run --rm --build test-runner bin/rails test test/models/provider/openai/receipt_extractor_test.rb test/models/provider/openai/bank_statement_extractor_test.rb
```
Expected: FAIL — `NameError: uninitialized constant Provider::Openai::ReceiptExtractor`, and the `parse_amount` test fails with `Expected: 295480.0, Actual: 2.38` style mismatches.

- [ ] **Step 3: Fix `parse_amount` for dot-thousands strings**

In `app/models/provider/openai/bank_statement_extractor.rb`, replace `parse_amount`:

```ruby
    # PYG has no cents and uses "." as a thousands separator, so "295.480"
    # is 295480, not 295.48. The previous implementation stripped everything
    # but digits/dots/minus and called to_f, which turned "2.383.271" into
    # 2.383 -- a ~1,000,000x error. It never fired in practice only because
    # the text model returns real integers; the vision model used for
    # receipts returns these as strings.
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
```

- [ ] **Step 4: Write `ReceiptExtractor`**

Create `app/models/provider/openai/receipt_extractor.rb`:

```ruby
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
```

**Note on `parse_amount`:** `.allocate.send(...)` is deliberate — it reuses the single fixed implementation without instantiating a `BankStatementExtractor` (whose `initialize` requires `pdf_content`) and without duplicating the PYG parsing logic in two places. If a reviewer prefers, extracting `parse_amount` and `AMOUNT_FORMAT_RULE` into a shared `Provider::Openai::Concerns::PygAmount` module is an equally acceptable resolution — but do not copy-paste the parsing body.

- [ ] **Step 5: Make `AMOUNT_FORMAT_RULE` reachable**

`AMOUNT_FORMAT_RULE` is currently defined inside `BankStatementExtractor`'s `private` section, which makes the *constant* still publicly reachable in Ruby (constants ignore `private`), so `Provider::Openai::BankStatementExtractor::AMOUNT_FORMAT_RULE` already resolves. Verify this rather than assuming — run:

```bash
docker compose -f compose.prod.yml --profile test run --rm --build test-runner bin/rails runner 'puts Provider::Openai::BankStatementExtractor::AMOUNT_FORMAT_RULE'
```
Expected: prints the PYG rule text. If it instead raises `NameError`, move the constant above the `private` keyword in `bank_statement_extractor.rb` and re-run.

- [ ] **Step 6: Add the provider method**

In `app/models/provider/openai.rb`, add after the existing `extract_bank_statement` method:

```ruby
  def extract_receipt(image_content:, content_type:, model: "", family: nil)
    with_provider_response do
      effective_model = model.presence || VISION_MODEL

      trace = create_langfuse_trace(
        name: "openai.extract_receipt",
        input: { image_size: image_content&.bytesize, content_type: content_type }
      )

      result = ReceiptExtractor.new(
        client: bank_statement_client,
        image_content: image_content,
        content_type: content_type,
        model: effective_model
      ).extract

      upsert_langfuse_trace(trace: trace, output: { transaction_count: result[:transactions].size })

      result
    end
  end
```

- [ ] **Step 7: Route by document type in `PdfImport`**

In `app/models/pdf_import.rb`, change `extract_transactions` so a receipt uses the receipt extractor (keep the rest of the method — the `response.success?` check and the `update!(extracted_data:)` — exactly as it is):

```ruby
  def extract_transactions
    return unless statement_with_transactions?

    provider = Provider::Registry.get_provider(:openai)
    raise "AI provider not configured" unless provider

    response = if document_type == "receipt"
      provider.extract_receipt(
        image_content: pdf_file_content,
        content_type: pdf_file.content_type,
        family: family
      )
    else
      provider.extract_bank_statement(
        pdf_content: pdf_file_content,
        family: family
      )
    end

    unless response.success?
      error_message = response.error&.message || "Unknown extraction error"
      raise error_message
    end

    update!(extracted_data: response.data)
    response.data
  end
```

- [ ] **Step 8: Run the tests to verify they pass**

Run:
```bash
docker compose -f compose.prod.yml --profile test run --rm --build test-runner bin/rails test test/models/provider/openai/receipt_extractor_test.rb test/models/provider/openai/bank_statement_extractor_test.rb test/models/pdf_import_test.rb
```
Expected: PASS, 0 failures.

- [ ] **Step 9: Commit**

```bash
git add app/models/provider/openai/receipt_extractor.rb app/models/provider/openai.rb app/models/provider/openai/bank_statement_extractor.rb app/models/pdf_import.rb test/models/provider/openai/receipt_extractor_test.rb test/models/provider/openai/bank_statement_extractor_test.rb
git commit -m "feat: add ReceiptExtractor and fix PYG dot-thousands amount parsing"
```

---

## Task 4: Accept image uploads in the controller

The last piece: route `.jpg`/`.jpeg`/`.png` to `create_pdf_import` instead of the dead vector-store branch.

**Files:**
- Modify: `app/controllers/imports_controller.rb` (`create_document_import`, around line 155-195)
- Test: `test/controllers/imports_controller_test.rb`

**Interfaces:**
- Consumes: everything from Tasks 1-3 (the uploaded image now flows through classification and receipt extraction).
- Produces: uploading a `.jpg`/`.jpeg`/`.png` through the existing "Importar documento" form creates a `PdfImport` and enqueues `ProcessPdfJob`, exactly as a PDF upload does.

- [ ] **Step 1: Write the failing test**

Add to `test/controllers/imports_controller_test.rb` (inside the existing class):

```ruby
  test "uploading a receipt photo creates a PdfImport" do
    file = Rack::Test::UploadedFile.new(
      Rails.root.join("test/fixtures/files/receipt.jpg"), "image/jpeg"
    )

    assert_difference -> { PdfImport.count }, 1 do
      post imports_path, params: { import: { import_file: file } }
    end

    import = PdfImport.order(created_at: :desc).first
    assert import.pdf_file.attached?
    assert_equal "image/jpeg", import.pdf_file.content_type
  end
```

Create the fixture image. A tiny valid JPEG is enough — the controller only checks size and extension, and the job is not executed in this test:

```bash
mkdir -p test/fixtures/files
printf '\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x00\x00\x01\x00\x01\x00\x00\xff\xdb\x00C\x00\xff\xd9' > test/fixtures/files/receipt.jpg
```

- [ ] **Step 2: Run the test to verify it fails**

Run:
```bash
docker compose -f compose.prod.yml --profile test run --rm --build test-runner bin/rails test test/controllers/imports_controller_test.rb
```
Expected: FAIL — `PdfImport.count` did not change by 1 (the upload currently falls through to the vector-store branch).

- [ ] **Step 3: Route images to the PDF import path**

In `app/controllers/imports_controller.rb`, inside `create_document_import`, replace the `if ext == ".pdf"` block with:

```ruby
      if ext == ".pdf"
        unless valid_pdf_file?(file)
          redirect_to new_import_path, alert: t("imports.create.invalid_pdf")
          return
        end

        create_pdf_import(file)
        return
      end

      # A photographed receipt takes the same path as a PDF: PdfImport holds
      # the bytes, ProcessPdfJob classifies them, and a `receipt`
      # classification triggers extraction. Skips valid_pdf_file?, which
      # checks for a %PDF- magic header an image will never have.
      if IMAGE_IMPORT_EXTENSIONS.include?(ext)
        create_pdf_import(file)
        return
      end
```

And add the constant at the top of the class, immediately after the `class ImportsController < ApplicationController` line:

```ruby
  IMAGE_IMPORT_EXTENSIONS = %w[.jpg .jpeg .png].freeze
```

- [ ] **Step 4: Run the test to verify it passes**

Run:
```bash
docker compose -f compose.prod.yml --profile test run --rm --build test-runner bin/rails test test/controllers/imports_controller_test.rb
```
Expected: PASS, 0 failures.

- [ ] **Step 5: Run the full suite for regressions**

This task changes a shared upload path, so run everything:
```bash
docker compose -f compose.prod.yml --profile test run --rm --build test-runner
```
Expected: 0 failures, 0 errors (the suite was 3688 runs / 0 failures / 60 skips as of 2026-07-28 — a different total is fine as long as failures and errors are 0).

- [ ] **Step 6: Commit**

```bash
git add app/controllers/imports_controller.rb test/controllers/imports_controller_test.rb test/fixtures/files/receipt.jpg
git commit -m "feat: accept receipt photos (jpg/png) in the document import flow"
```

---

## Post-implementation manual verification (not automated)

After all 4 tasks are merged and deployed to `alejandro-vm`:

1. Photograph a real receipt with the phone and upload it through "Importar documento" on https://finance.cd-co.com.py.
2. Confirm the import page shows document type "Factura" (es) and reaches `pending` status with 1 row.
3. Confirm the extracted merchant, date, and amount match the paper receipt — **especially the amount's magnitude** (a receipt for ₲55.000 must import as 55000, not 55). This is the single most likely thing to be wrong in real use, and it is why the PYG rule is stated explicitly in both the prompt and `parse_amount`.
4. Assign the account, publish the row, and confirm the transaction appears in the account's transaction list.

If the extracted amount or merchant is consistently wrong on real photos (as opposed to the synthetic tests), the lever to pull first is `ReceiptExtractor#instructions` — not the model, and not `parse_amount`, both of which are verified.
