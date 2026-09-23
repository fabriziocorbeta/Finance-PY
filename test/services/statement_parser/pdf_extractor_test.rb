require "test_helper"

module StatementParser
  class PdfExtractorTest < ActiveSupport::TestCase
    test "raises ExtractionError on corrupt data" do
      extractor = PdfExtractor.new("not a pdf")
      assert_raises(StatementParser::ExtractionError) { extractor.extract }
    end

    test "raises ExtractionError on empty bytes" do
      extractor = PdfExtractor.new("")
      assert_raises(StatementParser::ExtractionError) { extractor.extract }
    end

    test "returns String on valid PDF" do
      bytes = Rails.root.join("test/fixtures/files/imports/sample_bank_statement.pdf").binread
      extractor = PdfExtractor.new(bytes)
      text = extractor.extract
      assert_kind_of String, text
      assert_includes text, "MPESA"
    end

    test "raises ExtractionError when the PDF exceeds the page limit" do
      bytes = Rails.root.join("test/fixtures/files/imports/sample_bank_statement.pdf").binread
      original_max = PdfExtractor::MAX_PAGES
      PdfExtractor.send(:remove_const, :MAX_PAGES)
      PdfExtractor.const_set(:MAX_PAGES, 1) # fixture has 3 pages

      error = assert_raises(StatementParser::ExtractionError) { PdfExtractor.new(bytes).extract }
      assert_match(/páginas/, error.message)
    ensure
      PdfExtractor.send(:remove_const, :MAX_PAGES)
      PdfExtractor.const_set(:MAX_PAGES, original_max)
    end
  end
end
