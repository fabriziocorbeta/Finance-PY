require "test_helper"

class Assistant::Function::ImportBankStatementTest < ActiveSupport::TestCase
  setup do
    @pdf_import = imports(:pdf_processed) # family: dylan_family, document_type: bank_statement
    @restricted_user = users(:family_member) # writable: depository (full_control); NOT writable: credit_card (read_only), investment (no share)
    @function = Assistant::Function::ImportBankStatement.new(@restricted_user)
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
end
