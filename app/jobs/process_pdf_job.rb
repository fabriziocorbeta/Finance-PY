class ProcessPdfJob < ApplicationJob
  queue_as :medium_priority

  def perform(pdf_import)
    return unless pdf_import.is_a?(PdfImport)
    return unless pdf_import.pdf_uploaded?
    return if pdf_import.status == "complete"
    return if pdf_import.ai_processed? && (!pdf_import.statement_with_transactions? || pdf_import.rows_count > 0)

    pdf_import.update!(status: :importing)

    begin
      page_count = check_pdf_page_quota!(pdf_import)

      process_result = pdf_import.process_with_ai

      # Recorded only after process_with_ai succeeds (E5 corrector round 1
      # fix): this used to be recorded inside enforce_pdf_page_quota!, before
      # process_with_ai ran at all, so a family whose PDF failed to process
      # still had those pages charged against their daily cap -- contradicting
      # this file's own original comment and StatementParseJob's behavior
      # (which already recorded post-extraction). If process_with_ai raises,
      # control never reaches this line and nothing is charged.
      UsageQuota.record_pdf_pages!(pdf_import.family, page_count)
      document_type = resolve_document_type(pdf_import, process_result)
      upload_to_vector_store(pdf_import, document_type: document_type)

      # For statements with transactions (bank/credit card), extract and generate import rows
      if statement_with_transactions?(document_type)
        Rails.logger.info("ProcessPdfJob: Extracting transactions for #{document_type} import #{pdf_import.id}")
        pdf_import.extract_transactions
        Rails.logger.info("ProcessPdfJob: Extracted #{pdf_import.extracted_transactions.size} transactions")

        pdf_import.generate_rows_from_extracted_data
        pdf_import.sync_mappings
        Rails.logger.info("ProcessPdfJob: Generated #{pdf_import.rows_count} import rows")
      end

      # Find the user who created this import (first admin or any user in the family)
      user = pdf_import.family.users.find_by(role: :admin) || pdf_import.family.users.first

      if user
        pdf_import.send_next_steps_email(user)
      end

      # Statements with extracted rows go to pending for user review/publish
      # Other document types are marked complete (no further action needed)
      final_status = statement_with_transactions?(document_type) && pdf_import.rows_count > 0 ? :pending : :complete
      pdf_import.update!(status: final_status)
    rescue StandardError => e
      sanitized_error = sanitize_error_message(e)
      Rails.logger.error("PDF processing failed for import #{pdf_import.id}: #{e.class.name} - #{sanitized_error}")
      begin
        pdf_import.update!(status: :failed, error: sanitized_error)
      rescue StandardError => update_error
        Rails.logger.error("Failed to update import status: #{update_error.message}")
      end
      raise
    end
  end

  private

    # E5: daily PDF-page quota (see UsageQuota). Counting pages is a cheap,
    # local PDF::Reader parse -- no network/AI call -- so it's worth doing
    # before the family's actual quota-consuming call (process_with_ai,
    # which uploads the PDF and pays for AI extraction) rather than after.
    # Only checks and returns the count here; the caller records it against
    # the family's daily counter after process_with_ai succeeds, so a family
    # whose PDF fails to process isn't charged for that attempt.
    def check_pdf_page_quota!(pdf_import)
      page_count = pdf_page_count(pdf_import)

      if UsageQuota.pdf_quota_exceeded?(pdf_import.family, additional_pages: page_count)
        raise I18n.t("imports.pdf_import.pdf_quota_exceeded")
      end

      page_count
    end

    def pdf_page_count(pdf_import)
      PDF::Reader.new(StringIO.new(pdf_import.pdf_file_content)).page_count
    rescue StandardError => e
      # A PDF page count that fails to parse here will fail identically
      # (and be reported the same way) a few lines later in process_with_ai
      # -- don't let a bad file dodge quota enforcement by treating the
      # count as unlimited, but don't block on it either; charge nothing
      # and let the real processing step raise the real error.
      Rails.logger.warn("ProcessPdfJob: could not count PDF pages for import #{pdf_import.id}: #{e.class.name}")
      0
    end

    def sanitize_error_message(error)
      case error
      when RuntimeError, ArgumentError
        I18n.t("imports.pdf_import.processing_failed_with_message",
               message: error.message.truncate(500))
      else
        I18n.t("imports.pdf_import.processing_failed_generic",
               error: error.class.name.demodulize)
      end
    end

    def upload_to_vector_store(pdf_import, document_type:)
      filename = pdf_import.pdf_file.filename.to_s
      file_content = pdf_import.pdf_file_content

      family_document = pdf_import.family.upload_document(
        file_content: file_content,
        filename: filename,
        metadata: { "type" => document_type }
      )

      return if family_document

      Rails.logger.warn("ProcessPdfJob: Vector store upload failed for import #{pdf_import.id}")
    end

    def resolve_document_type(pdf_import, process_result)
      return process_result.document_type if process_result.respond_to?(:document_type) && process_result.document_type.present?

      pdf_import.reload.document_type
    end

    def statement_with_transactions?(document_type)
      document_type.in?(%w[bank_statement credit_card_statement receipt])
    end
end
