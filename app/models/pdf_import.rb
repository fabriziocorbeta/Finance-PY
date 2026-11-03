class PdfImport < Import
  has_one_attached :pdf_file, dependent: :purge_later

  validates :document_type, inclusion: { in: DOCUMENT_TYPES }, allow_nil: true

  def import!
    raise "Account required for PDF import" unless account.present?

    transaction do
      mappings.each(&:create_mappable!)

      new_transactions = []
      updated_entries = []
      claimed_entry_ids = Set.new # Track entries we've already claimed in this import
      adapter = Account::ProviderImportAdapter.new(account)

      rows.each do |row|
        category = mappings.categories.mappable_for(row.category)

        # Same dedup rule TransactionImport (CSV) already applies: skip creating a
        # new row when one already exists for this account/date/amount/currency
        # without an external_id. Without this, re-uploading a statement that
        # overlaps a previous import (or a charge already entered manually)
        # silently doubles the entry.
        duplicate_entry = adapter.find_duplicate_transaction(
          date: row.date_iso,
          amount: row.signed_amount,
          currency: row.currency,
          exclude_entry_ids: claimed_entry_ids
        )

        if duplicate_entry
          duplicate_entry.transaction.category = category if category.present?
          duplicate_entry.notes = row.notes if row.notes.present?
          duplicate_entry.import = self
          duplicate_entry.import_locked = true
          updated_entries << duplicate_entry
          claimed_entry_ids.add(duplicate_entry.id)
        else
          new_transactions << Transaction.new(
            category: category,
            entry: Entry.new(
              account: account,
              date: row.date_iso,
              amount: row.signed_amount,
              name: row.name,
              currency: row.currency,
              notes: row.notes,
              import: self,
              import_locked: true
            )
          )
        end
      end

      updated_entries.each do |entry|
        entry.transaction.save!
        entry.save!
      end

      Transaction.import!(new_transactions, recursive: true) if new_transactions.any?
    end
  end

  def pdf_uploaded?
    pdf_file.attached?
  end

  def ai_processed?
    ai_summary.present?
  end

  def process_with_ai_later
    ProcessPdfJob.perform_later(self)
  end

  def process_with_ai
    provider = Provider::Registry.get_provider(:openai)
    raise "AI provider not configured" unless provider
    raise "AI provider does not support PDF processing" unless provider.supports_pdf_processing?

    response = provider.process_pdf(
      pdf_content: pdf_file_content,
      family: family,
      content_type: pdf_file.content_type
    )

    unless response.success?
      error_message = response.error&.message || "Unknown PDF processing error"
      raise error_message
    end

    result = response.data
    update!(
      ai_summary: result.summary,
      document_type: result.document_type
    )

    result
  end

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

  def bank_statement?
    document_type == "bank_statement"
  end

  def statement_with_transactions?
    document_type.in?(%w[bank_statement credit_card_statement receipt])
  end

  def has_extracted_transactions?
    extracted_data.present? && extracted_data["transactions"].present?
  end

  def extracted_transactions
    extracted_data&.dig("transactions") || []
  end

  def generate_rows_from_extracted_data
    transaction do
      rows.destroy_all

      unless has_extracted_transactions?
        update_column(:rows_count, 0)
        return
      end

      currency = account&.currency || family.currency

      mapped_rows = extracted_transactions.map.with_index(1) do |txn, index|
        {
          import_id: id,
          source_row_number: index,
          date: format_date_for_import(txn["date"]),
          amount: txn["amount"].to_s,
          name: txn["name"].to_s,
          category: txn["category"].to_s,
          notes: txn["notes"].to_s,
          currency: currency
        }
      end

      Import::Row.insert_all!(mapped_rows) if mapped_rows.any?
      update_column(:rows_count, mapped_rows.size)
    end
  end

  def send_next_steps_email(user)
    PdfImportMailer.with(
      user: user,
      pdf_import: self
    ).next_steps.deliver_later
  end

  def uploaded?
    pdf_uploaded?
  end

  def configured?
    ai_processed? && rows_count > 0
  end

  def cleaned?
    configured? && rows.all?(&:valid?)
  end

  def publishable?
    account.present? && statement_with_transactions? && cleaned? && mappings.all?(&:valid?)
  end

  def cleaned_from_validation_stats?(invalid_rows_count:)
    account.present? && statement_with_transactions? && super
  end

  def publishable_from_validation_stats?(invalid_rows_count:)
    account.present? && statement_with_transactions? && super
  end

  def column_keys
    %i[date amount name category notes]
  end

  def requires_csv_workflow?
    false
  end

  def pdf_file_content
    return nil unless pdf_file.attached?

    pdf_file.download
  end

  def required_column_keys
    %i[date amount]
  end

  def mapping_steps
    base = []
    # Only include CategoryMapping if rows have non-empty categories
    base << Import::CategoryMapping if rows.where.not(category: [ nil, "" ]).exists?
    # Note: PDF imports use direct account selection in the UI, not AccountMapping
    # AccountMapping is designed for CSV imports where rows have different account values
    base
  end

  private

    def format_date_for_import(date_str)
      return "" if date_str.blank?

      Date.parse(date_str).strftime(date_format)
    rescue ArgumentError
      date_str.to_s
    end
end
