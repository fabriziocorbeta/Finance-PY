require "test_helper"

class StatementImportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in @user = users(:family_admin)
    @family = @user.family
    @account = accounts(:depository)

    # Mirrors what StatementParser::ClaudeParser actually produces (see its
    # SYSTEM_PROMPT): amount_cents in minor units, negative=debit/positive=
    # credit, taken from the real fixture used elsewhere in this suite
    # (test/fixtures/files/imports/sample_bank_statement.pdf -- a real
    # 3-page statement: "Pay Bill... 3,020.00" paid out and "B2C Payment...
    # 10,000.00" paid in).
    @raw_transactions = [
      {
        date: "2025-06-17", description: "Pay Bill Online to 244441 - SAFARICOM",
        amount_cents: -302_000, currency: "KES", transaction_type: "debit", balance_cents: nil
      },
      {
        date: "2025-06-15", description: "B2C Payment from SAFARICOM",
        amount_cents: 1_000_000, currency: "KES", transaction_type: "credit", balance_cents: nil
      }
    ]

    @import = StatementImport.create!(
      family: @family, user: @user, status: :review,
      bank_name: "Otro", raw_transactions: @raw_transactions, parsed_count: @raw_transactions.size
    )
  end

  test "confirm imports transactions with correct amount (major units) and sign" do
    assert_difference -> { Entry.count }, 2 do
      post confirm_statement_import_url(@import), params: { account_id: @account.id }
    end

    debit = Entry.find_by(name: "Pay Bill Online to 244441 - SAFARICOM")
    credit = Entry.find_by(name: "B2C Payment from SAFARICOM")

    # amount_cents -302_000 (minor units) -> -3020.0 (major units), not -302000
    assert_equal(-3020.0, debit.amount.to_f)
    assert_equal 10_000.0, credit.amount.to_f
    assert_equal "KES", debit.currency

    assert_redirected_to accounts_url
    @import.reload
    assert @import.completed?
    assert_equal 2, @import.imported_count
  end

  test "double confirm (double click) does not duplicate transactions" do
    post confirm_statement_import_url(@import), params: { account_id: @account.id }
    assert_equal 2, Entry.where(name: [ "Pay Bill Online to 244441 - SAFARICOM", "B2C Payment from SAFARICOM" ]).count

    assert_no_difference -> { Entry.count } do
      post confirm_statement_import_url(@import), params: { account_id: @account.id }
    end
  end

  test "confirm skips a row with an invalid currency instead of crashing the batch" do
    @import.update!(raw_transactions: @raw_transactions + [
      { date: "2025-06-16", description: "Garbage row", amount_cents: -100, currency: "NOTACURRENCY", transaction_type: "debit" }
    ], parsed_count: 3)

    assert_difference -> { Entry.count }, 2 do
      post confirm_statement_import_url(@import), params: { account_id: @account.id }
    end
    assert_not Entry.exists?(name: "Garbage row")
  end

  test "confirm skips a row with a missing date instead of crashing the batch" do
    @import.update!(raw_transactions: @raw_transactions + [
      { date: nil, description: "No date row", amount_cents: -100, currency: "KES", transaction_type: "debit" }
    ], parsed_count: 3)

    assert_difference -> { Entry.count }, 2 do
      post confirm_statement_import_url(@import), params: { account_id: @account.id }
    end
    assert_not Entry.exists?(name: "No date row")
  end

  test "confirm requires a valid account" do
    assert_no_difference -> { Entry.count } do
      post confirm_statement_import_url(@import), params: { account_id: "not-a-real-id" }
    end
    assert_redirected_to @import
  end

  test "create rejects a file larger than the limit" do
    oversized = fixture_file_upload("imports/sample_bank_statement.pdf", "application/pdf")
    StatementImportsController::MAX_FILE_SIZE.then do |real_limit|
      StatementImportsController.send(:remove_const, :MAX_FILE_SIZE)
      StatementImportsController.const_set(:MAX_FILE_SIZE, 10)

      assert_no_difference -> { StatementImport.count } do
        post statement_imports_url, params: { statement_import: { bank_name: "Otro", source_file: oversized } }
      end
      assert_response :unprocessable_entity

      StatementImportsController.send(:remove_const, :MAX_FILE_SIZE)
      StatementImportsController.const_set(:MAX_FILE_SIZE, real_limit)
    end
  end

  test "create rejects a file whose real bytes are not a PDF even if it claims to be one" do
    spoofed = fixture_file_upload("test.txt", "application/pdf")

    assert_no_difference -> { StatementImport.count } do
      post statement_imports_url, params: { statement_import: { bank_name: "Otro", source_file: spoofed } }
    end
    assert_response :unprocessable_entity
  end

  test "create accepts a real PDF" do
    pdf = fixture_file_upload("imports/sample_bank_statement.pdf", "application/pdf")

    assert_difference -> { StatementImport.count }, 1 do
      post statement_imports_url, params: { statement_import: { bank_name: "Otro", source_file: pdf } }
    end
    assert_response :redirect
  end

  test "create rejects a non-file source_file param instead of crashing with a 500" do
    assert_no_difference -> { StatementImport.count } do
      post statement_imports_url, params: { statement_import: { bank_name: "Otro", source_file: "not-a-file" } }
    end
    assert_response :unprocessable_entity
  end

  test "create rejects a nested-hash source_file param instead of crashing with a 500" do
    assert_no_difference -> { StatementImport.count } do
      post statement_imports_url, params: { statement_import: { bank_name: "Otro", source_file: { foo: "bar" } } }
    end
    assert_response :unprocessable_entity
  end

  test "confirm skips a row with a missing amount instead of importing a fabricated $0.00 entry" do
    @import.update!(raw_transactions: @raw_transactions + [
      { date: "2025-06-16", description: "No amount row", amount_cents: nil, currency: "KES", transaction_type: "debit" }
    ], parsed_count: 3)

    assert_difference -> { Entry.count }, 2 do
      post confirm_statement_import_url(@import), params: { account_id: @account.id }
    end
    assert_not Entry.exists?(name: "No amount row")
  end

  test "confirm skips a row with a garbage (non-numeric) amount" do
    @import.update!(raw_transactions: @raw_transactions + [
      { date: "2025-06-16", description: "Garbage amount row", amount_cents: "not-a-number", currency: "KES", transaction_type: "debit" }
    ], parsed_count: 3)

    assert_difference -> { Entry.count }, 2 do
      post confirm_statement_import_url(@import), params: { account_id: @account.id }
    end
    assert_not Entry.exists?(name: "Garbage amount row")
  end

  test "confirm skips a row with a blank description and still imports the other valid rows" do
    @import.update!(raw_transactions: @raw_transactions + [
      { date: "2025-06-16", description: nil, amount_cents: -100, currency: "KES", transaction_type: "debit" }
    ], parsed_count: 3)

    assert_difference -> { Entry.count }, 2 do
      post confirm_statement_import_url(@import), params: { account_id: @account.id }
    end
    @import.reload
    assert @import.completed?
    assert_equal 2, @import.imported_count
  end

  test "confirm does not abort the whole batch when one row hits an Entry validation error outside external_id" do
    # Simulate a row that passes ParsedTransaction#valid? but still trips an
    # Entry validation not covered by that check (e.g. a date older than
    # Entry.min_supported_date), to make sure a single bad row no longer
    # rolls back the entire transaction.
    @import.update!(raw_transactions: @raw_transactions + [
      { date: "1900-01-01", description: "Too old row", amount_cents: -100, currency: "KES", transaction_type: "debit" }
    ], parsed_count: 3)

    assert_difference -> { Entry.count }, 2 do
      post confirm_statement_import_url(@import), params: { account_id: @account.id }
    end
    @import.reload
    assert @import.completed?
    assert_equal 2, @import.imported_count
    assert_not Entry.exists?(name: "Too old row")
  end
end
