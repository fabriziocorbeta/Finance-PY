module StatementParser
  class TransactionBuilder
    # statement_import: optional StatementImport, used to derive a stable
    # external_id per row so a repeated confirm (double click, retried
    # request) does not create duplicate entries -- Entry already enforces
    # uniqueness on [account_id, source, external_id] (see
    # index_entries_on_account_source_and_external_id).
    def initialize(account, statement_import: nil)
      @account = account
      @statement_import = statement_import
    end

    # Returns an unsaved Entry with a built Transaction entryable.
    #
    # Entry#amount is a decimal column (numeric(19,4), major currency units --
    # see db/structure.sql), matching every other importer's convention
    # (Import::Row#signed_amount, UpayImport, etc. all assign decimal amounts,
    # never cents). ParsedTransaction#amount_cents is minor units (cents),
    # per StatementParser::ClaudeParser's prompt ("multiply by 100"), so it
    # must be divided back down before being stored on Entry.
    #
    # Sign convention: negative = money leaving the account (debit), positive
    # = money arriving (credit). This already matches the rest of the app
    # (Import::Row#apply_transaction_signage_convention: "positive quantities
    # == inflows") and ClaudeParser's prompt, so no sign flip is needed here.
    def build(parsed, row_index: nil)
      transaction = Transaction.new

      Entry.new(
        account: @account,
        date: parsed.date,
        name: parsed.description,
        amount: parsed.amount_cents.to_d / 100,
        currency: parsed.currency,
        entryable: transaction,
        source: entry_source,
        external_id: external_id_for(parsed, row_index)
      )
    end

    def build_and_save!(parsed, row_index: nil)
      raise ArgumentError, "Account must be persisted before importing transactions" unless @account.persisted?
      entry = build(parsed, row_index: row_index)
      entry.save!
      entry
    end

    private

      def entry_source
        @statement_import.present? ? "statement_import" : nil
      end

      # Deterministic per-row id: same import + same row index + same content
      # always hashes to the same value, so re-running confirm (e.g. a double
      # submit) on an already-imported row collides with the unique index
      # instead of creating a second entry. Different rows with identical
      # content are still distinguished by their row_index.
      def external_id_for(parsed, row_index)
        return nil if @statement_import.blank? || row_index.nil?

        Digest::SHA256.hexdigest(
          [
            @statement_import.id,
            row_index,
            parsed.date,
            parsed.amount_cents,
            parsed.currency,
            parsed.description
          ].join("|")
        )
      end
  end
end
