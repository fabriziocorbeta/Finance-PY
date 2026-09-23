module StatementParser
  class PdfExtractor
    # A real bank statement is a handful of pages; anything beyond this is
    # either the wrong document or an attempt to force minutes of PDF::Reader
    # parsing + a huge, expensive AI extraction call (no size/page limit
    # existed here before -- see StatementImportsController::MAX_FILE_SIZE
    # for the companion byte-size limit enforced at upload time).
    MAX_PAGES = 40

    def initialize(bytes)
      @bytes = bytes
    end

    def extract
      reader = PDF::Reader.new(StringIO.new(@bytes))

      if reader.page_count > MAX_PAGES
        raise ExtractionError, "El PDF tiene #{reader.page_count} páginas; el máximo permitido es #{MAX_PAGES}."
      end

      text = reader.pages.map(&:text).join("\n")
      raise ExtractionError, "PDF produced no text (may be scanned image)" if text.strip.empty?
      text
    rescue PDF::Reader::MalformedPDFError, PDF::Reader::EncryptedPDFError => e
      raise ExtractionError, "PDF extraction failed: #{e.message}"
    rescue ArgumentError => e
      raise ExtractionError, "Invalid PDF data: #{e.message}"
    end
  end
end
