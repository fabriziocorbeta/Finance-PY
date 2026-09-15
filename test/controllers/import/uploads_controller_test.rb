require "test_helper"

class Import::UploadsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in @user = users(:family_admin)
    @import = imports(:transaction)
  end

  test "show" do
    get import_upload_url(@import)
    assert_response :success
  end

  test "uploads valid csv by copy and pasting" do
    patch import_upload_url(@import), params: {
      import: {
        raw_file_str: file_fixture("imports/valid.csv").read,
        col_sep: ","
      }
    }

    assert_redirected_to import_configuration_url(@import, template_hint: true)
    assert_equal "CSV uploaded successfully.", flash[:notice]
  end

  test "uploads valid csv by file" do
    patch import_upload_url(@import), params: {
      import: {
        import_file: file_fixture_upload("imports/valid.csv"),
        col_sep: ","
      }
    }

    assert_redirected_to import_configuration_url(@import, template_hint: true)
    assert_equal "CSV uploaded successfully.", flash[:notice]
  end

  test "invalid csv cannot be uploaded" do
    patch import_upload_url(@import), params: {
      import: {
        import_file: file_fixture_upload("imports/invalid.csv"),
        col_sep: ","
      }
    }

    assert_response :unprocessable_entity
    assert_equal "Must be valid CSV with headers and at least one row of data", flash[:alert]
  end

  test "uploads a valid Upay csv and generates rows immediately, account required" do
    account = accounts(:depository)
    upay_import = @user.family.imports.create!(type: "UpayImport")

    patch import_upload_url(upay_import), params: {
      import: {
        import_file: file_fixture_upload("imports/upay_valid.csv"),
        account_id: account.id
      }
    }

    assert_redirected_to import_clean_url(upay_import)
    upay_import.reload
    assert_equal account, upay_import.account
    assert_equal 2, upay_import.rows_count
    assert_equal "35000", upay_import.rows_ordered.first.gross_amount
  end

  test "Upay upload requires an account" do
    upay_import = @user.family.imports.create!(type: "UpayImport")

    patch import_upload_url(upay_import), params: {
      import: {
        import_file: file_fixture_upload("imports/upay_valid.csv")
      }
    }

    assert_response :unprocessable_entity
    assert_equal 0, upay_import.reload.rows_count
  end
end
