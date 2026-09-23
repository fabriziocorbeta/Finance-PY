class StatementImportsController < ApplicationController
  before_action :set_import, only: %i[show confirm reject]

  MAX_FILE_SIZE = 25.megabytes
  BANKS = [ "Itaú Paraguay", "Banco Continental", "Visión Banco", "GNB Paraguay", "Otro" ].freeze

  def new
    @import = StatementImport.new
    @banks = BANKS
  end

  def create
    file = params.dig(:statement_import, :source_file)

    return render_new_with_error(t(".no_file")) if file.blank?

    if file.size > MAX_FILE_SIZE
      return render_new_with_error(t(".file_too_large", max_size: MAX_FILE_SIZE / 1.megabyte))
    end

    # Trust the actual file bytes (magic-byte sniffing via Marcel), not the
    # client-supplied Content-Type header, which is trivially spoofable and
    # would otherwise let a renamed/fake file reach the PDF pipeline.
    return render_new_with_error(t(".invalid_file_type")) unless pdf_file?(file)

    @import = StatementImport.new(
      family:    Current.family,
      user:      Current.user,
      bank_name: params.dig(:statement_import, :bank_name),
      status:    :pending
    )
    @import.source_file.attach(io: file.tempfile, filename: file.original_filename, content_type: "application/pdf")

    if @import.save
      StatementParseJob.perform_later(@import.id)
      redirect_to @import, notice: t(".success")
    else
      render_new_with_error(@import.errors.full_messages.to_sentence)
    end
  end

  def show
    @transactions = @import.review? ? @import.transactions_for_review : []
  end

  def confirm
    account = Current.family.accounts.find_by(id: params[:account_id])
    return redirect_to @import, alert: t(".account_not_found") unless account

    imported_count = 0

    StatementImport.transaction do
      # Row-level lock so two concurrent confirm requests (double click,
      # retried form submit) for the same import serialize instead of both
      # importing the transactions.
      @import.lock!
      unless @import.review?
        # Already completed/failed by this request or a concurrent one --
        # nothing left to do. Falls through to the redirect below.
        next
      end

      builder = StatementParser::TransactionBuilder.new(account, statement_import: @import)
      rows = @import.transactions_for_review

      rows.each_with_index do |parsed, index|
        next unless parsed.valid?

        begin
          builder.build_and_save!(parsed, row_index: index)
          imported_count += 1
        rescue ActiveRecord::RecordInvalid => e
          # A duplicate external_id means this exact row was already
          # imported (e.g. a previous confirm that partially succeeded);
          # skip it instead of failing the whole batch. Any other
          # validation error is a real problem and should surface.
          raise unless e.record.errors.of_kind?(:external_id, :taken)
        end
      end

      @import.update!(status: :completed, imported_count: imported_count)
    end

    if @import.completed?
      redirect_to accounts_path, notice: t(".success", count: imported_count)
    else
      redirect_to @import
    end
  end

  def reject
    return redirect_to @import unless @import.review?

    @import.update!(status: :failed, error_message: "Rechazado por el usuario")
    redirect_to new_statement_import_path, notice: "Importación descartada."
  end

  private

    def set_import
      @import = Current.family.statement_imports.find(params[:id])
    end

    def render_new_with_error(message)
      @import = StatementImport.new
      @banks = BANKS
      flash.now[:alert] = message
      render :new, status: :unprocessable_entity
    end

    # Sniffs the real file type from its bytes (magic numbers), not the
    # client-supplied Content-Type header. A renamed .exe or .html file can
    # freely claim "application/pdf" on upload; Marcel::MimeType.for(io)
    # inspects the actual content the same way ActiveStorage's own analyzers
    # do, so we can't be tricked into feeding non-PDF bytes to PDF::Reader
    # and the AI parser downstream.
    def pdf_file?(file)
      tempfile = file.tempfile
      tempfile.rewind
      # Deliberately pass neither `name:` nor `declared_type:` -- both are
      # attacker-controlled (the upload's filename and Content-Type header)
      # and Marcel falls back to them when the magic-byte sniff on the
      # content itself is inconclusive, which would let a non-PDF file
      # dressed up with a ".pdf" name or an "application/pdf" header sail
      # through. Magic-byte-only detection is what we want here.
      Marcel::MimeType.for(tempfile) == "application/pdf"
    ensure
      tempfile&.rewind
    end
end
