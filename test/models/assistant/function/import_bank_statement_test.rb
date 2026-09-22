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
end
