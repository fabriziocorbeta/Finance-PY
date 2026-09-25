require "test_helper"

module StatementParser
  class TransactionBuilderTest < ActiveSupport::TestCase
    def setup
      @parsed = ParsedTransaction.new(
        date: "2026-05-01",
        description: "SUPERMERCADO STOCK",
        amount_cents: -15_000_000,
        currency: "PYG",
        transaction_type: :debit,
        balance_cents: 85_000_000
      )
    end

    test "build returns an Entry instance" do
      account = Account.new
      builder = TransactionBuilder.new(account)
      entry = builder.build(@parsed)
      assert_kind_of Entry, entry
    end

    test "built entry has correct date" do
      account = Account.new
      builder = TransactionBuilder.new(account)
      entry = builder.build(@parsed)
      assert_equal Date.new(2026, 5, 1), entry.date
    end

    test "built entry has correct name from description" do
      account = Account.new
      builder = TransactionBuilder.new(account)
      entry = builder.build(@parsed)
      assert_equal "SUPERMERCADO STOCK", entry.name
    end

    test "built entry amount is converted from cents to major currency units" do
      account = Account.new
      builder = TransactionBuilder.new(account)
      entry = builder.build(@parsed)
      # Entry#amount is numeric(19,4) (major units), while ParsedTransaction
      # carries amount_cents (minor units) -- 15_000_000 cents == 150_000 Gs.
      assert_equal(-150_000, entry.amount)
    end

    test "built entry has correct currency" do
      account = Account.new
      builder = TransactionBuilder.new(account)
      entry = builder.build(@parsed)
      assert_equal "PYG", entry.currency
    end

    test "built entry is not persisted" do
      account = Account.new
      builder = TransactionBuilder.new(account)
      entry = builder.build(@parsed)
      assert_not entry.persisted?
    end

    test "built entry has a Transaction entryable" do
      account = Account.new
      builder = TransactionBuilder.new(account)
      entry = builder.build(@parsed)
      assert_kind_of Transaction, entry.entryable
    end

    test "built entry references the given account" do
      account = Account.new
      builder = TransactionBuilder.new(account)
      entry = builder.build(@parsed)
      assert_equal account, entry.account
    end

    test "without a statement_import, no external_id or source is set" do
      account = Account.new
      builder = TransactionBuilder.new(account)
      entry = builder.build(@parsed)
      assert_nil entry.external_id
      assert_nil entry.source
    end

    test "same statement_import + row_index + content produces the same external_id" do
      account = Account.new
      import = StatementImport.new(id: SecureRandom.uuid)
      builder = TransactionBuilder.new(account, statement_import: import)

      first = builder.build(@parsed, row_index: 0)
      second = builder.build(@parsed, row_index: 0)

      assert_equal "statement_import", first.source
      assert_not_nil first.external_id
      assert_equal first.external_id, second.external_id
    end

    test "different row_index for identical content produces different external_id" do
      account = Account.new
      import = StatementImport.new(id: SecureRandom.uuid)
      builder = TransactionBuilder.new(account, statement_import: import)

      first = builder.build(@parsed, row_index: 0)
      second = builder.build(@parsed, row_index: 1)

      assert_not_equal first.external_id, second.external_id
    end

    test "double build_and_save! of the same row raises on the second attempt (dedupe)" do
      account = accounts(:depository)
      import = StatementImport.create!(
        family: account.family,
        user: account.family.users.first,
        status: :review
      )
      builder = TransactionBuilder.new(account, statement_import: import)

      builder.build_and_save!(@parsed, row_index: 0)

      assert_raises(ActiveRecord::RecordInvalid) do
        builder.build_and_save!(@parsed, row_index: 0)
      end
    end
  end
end
