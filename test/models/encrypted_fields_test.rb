require "test_helper"

# Free-text user data must be unreadable in the database (DB leak / backup theft
# / owner with SQL access), while the model still returns plaintext.
class EncryptedFieldsTest < ActiveSupport::TestCase
  test "account notes are stored encrypted" do
    account = accounts(:depository)
    account.update!(notes: "secreto-de-prueba-123")

    raw = Account.connection.select_value("SELECT notes FROM accounts WHERE id = '#{account.id}'")
    assert_not_includes raw, "secreto-de-prueba-123"
    assert_equal "secreto-de-prueba-123", account.reload.notes
  end
end
