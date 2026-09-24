require "test_helper"

class Assistant::Function::ImportBankStatementTest < ActiveSupport::TestCase
  setup do
    @pdf_import = imports(:pdf_processed) # family: dylan_family, document_type: bank_statement
    @restricted_user = users(:family_member) # writable: depository (full_control); NOT writable: credit_card (read_only), investment (no share)
    @function = Assistant::Function::ImportBankStatement.new(@restricted_user)
    @previous_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    Rails.cache = @previous_cache
  end

  test "rejects an account the user cannot write to (no share at all)" do
    result = @function.call(
      "pdf_import_id" => @pdf_import.id,
      "account_id" => accounts(:investment).id
    )

    assert_equal false, result[:success]
    assert_equal "account_not_found", result[:error]
  end

  test "rejects an account the user only has read-only access to" do
    result = @function.call(
      "pdf_import_id" => @pdf_import.id,
      "account_id" => accounts(:credit_card).id
    )

    assert_equal false, result[:success]
    assert_equal "account_not_found", result[:error]
  end

  test "available_accounts (when account_id is missing) excludes accounts the user cannot write to" do
    result = @function.call("pdf_import_id" => @pdf_import.id)

    assert_equal false, result[:success]
    assert_equal "account_required", result[:error]

    ids = result[:available_accounts].map { |a| a[:id] }
    assert_not_includes ids, accounts(:investment).id
    assert_not_includes ids, accounts(:credit_card).id
  end

  test "account owner is not blocked by the account_not_found check" do
    function = Assistant::Function::ImportBankStatement.new(users(:family_admin))

    result = function.call(
      "pdf_import_id" => @pdf_import.id,
      "account_id" => accounts(:investment).id
    )

    assert_not_equal "account_not_found", result[:error]
  end

  # E6 security requirement: the assistant may stage an import from extracted
  # PDF data, but it must NEVER publish it (i.e. write real Transaction/Entry
  # records) on its own -- only an explicit user action in the UI (the
  # imports#publish controller action) can do that.
  test "extracting a statement stages a pending import and never writes transactions itself" do
    function = Assistant::Function::ImportBankStatement.new(users(:family_admin))
    account = accounts(:depository)

    extracted = {
      transactions: [
        { date: "2024-01-05", amount: "42.50", name: "Coffee Shop", category: "Food & Drink", notes: "" }
      ],
      period: { start_date: "2024-01-01", end_date: "2024-01-31" },
      account_holder: "Dylan Family"
    }

    provider = mock
    provider.expects(:extract_bank_statement).returns(
      Provider::Response.new(success?: true, data: extracted, error: nil)
    )
    Provider::Registry.stubs(:get_provider).with(:openai).returns(provider)

    entry_count_before = Entry.count

    result = function.call(
      "pdf_import_id" => @pdf_import.id,
      "account_id" => account.id
    )

    assert_equal true, result[:success]

    import = account.family.imports.find(result[:import_id])

    # Rows were staged for review, but the import itself is still pending --
    # generate_rows_from_csv never transitions status, and the function never
    # calls Import#publish / #publish_later.
    assert import.pending?, "expected the import to stay pending, got #{import.status.inspect}"
    assert import.rows.any?, "expected rows to have been generated for review"

    # No real ledger entries were created as a side effect of the assistant
    # function -- only Import#publish (triggered from the UI) creates those.
    assert_equal entry_count_before, Entry.count
  end

  # E5 corrector round 1: this tool-call path is reachable directly by the
  # assistant loop (and, via it, MCP-driven callers), and was completely
  # unmetered by both the LLM token quota and the PDF-page quota, even
  # though it triggers a real, costly AI extraction call. Verify both quotas
  # are now enforced before the provider is ever called.
  test "rejects the extraction once the family's daily LLM token quota is used up, without calling the provider" do
    LlmUsage.create!(
      family: @pdf_import.family,
      provider: "openai",
      model: "gpt-4.1",
      operation: "chat_response",
      prompt_tokens: UsageQuota::DAILY_LLM_TOKEN_LIMIT,
      completion_tokens: 0,
      total_tokens: UsageQuota::DAILY_LLM_TOKEN_LIMIT
    )
    Provider::Registry.expects(:get_provider).never

    result = @function.call("pdf_import_id" => @pdf_import.id, "account_id" => accounts(:depository).id)

    assert_equal false, result[:success]
    assert_equal "llm_quota_exceeded", result[:error]
  end

  test "rejects the extraction when it would exceed the family's daily PDF-page quota, without calling the provider" do
    UsageQuota.stubs(:pdf_quota_exceeded?).returns(true)
    Provider::Registry.expects(:get_provider).never

    result = @function.call("pdf_import_id" => @pdf_import.id, "account_id" => accounts(:depository).id)

    assert_equal false, result[:success]
    assert_equal "pdf_quota_exceeded", result[:error]
  end

  test "records the family's PDF-page quota only after a successful extraction" do
    pdf_content = file_fixture("imports/sample_bank_statement.pdf").binread
    @pdf_import.pdf_file.attach(io: StringIO.new(pdf_content), filename: "statement.pdf", content_type: "application/pdf")

    response = stub(
      success?: true,
      data: {
        transactions: [ { date: "2024-01-01", amount: 10, name: "Coffee", category: "Food", notes: nil } ],
        period: "Jan 2024",
        account_holder: "Test"
      }
    )
    provider = stub
    provider.expects(:extract_bank_statement).returns(response)
    Provider::Registry.expects(:get_provider).with(:openai).returns(provider)

    assert_equal 0, UsageQuota.pdf_pages_used_today(@pdf_import.family)

    result = @function.call("pdf_import_id" => @pdf_import.id, "account_id" => accounts(:depository).id)

    assert_equal true, result[:success]
    assert_operator UsageQuota.pdf_pages_used_today(@pdf_import.family), :>, 0
  end

  test "does not record PDF-page quota when the extraction fails" do
    @pdf_import.pdf_file.attach(
      io: StringIO.new(file_fixture("imports/sample_bank_statement.pdf").binread),
      filename: "statement.pdf",
      content_type: "application/pdf"
    )

    response = stub(success?: false, error: stub(message: "boom"))
    provider = stub
    provider.expects(:extract_bank_statement).returns(response)
    Provider::Registry.expects(:get_provider).with(:openai).returns(provider)

    result = @function.call("pdf_import_id" => @pdf_import.id, "account_id" => accounts(:depository).id)

    assert_equal false, result[:success]
    assert_equal 0, UsageQuota.pdf_pages_used_today(@pdf_import.family)
  end
end
