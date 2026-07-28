require "test_helper"

class Provider::Openai::PdfProcessorTest < ActiveSupport::TestCase
  setup do
    @client = mock("openai_client")
  end

  def build_processor(content_type:, pdf_content: "fake-bytes")
    Provider::Openai::PdfProcessor.new(
      @client,
      model: "test-model",
      pdf_content: pdf_content,
      custom_provider: true,
      langfuse_trace: nil,
      family: nil,
      max_response_tokens: 1000,
      content_type: content_type
    )
  end

  test "treats an image content type as image input" do
    processor = build_processor(content_type: "image/jpeg")
    assert processor.send(:image_input?)
  end

  test "treats a pdf content type as non-image input" do
    processor = build_processor(content_type: "application/pdf")
    assert_not processor.send(:image_input?)
  end

  test "treats a missing content type as non-image input" do
    processor = build_processor(content_type: nil)
    assert_not processor.send(:image_input?)
  end

  test "sends image bytes straight to the vision model without shelling out to pdftoppm" do
    processor = build_processor(content_type: "image/jpeg", pdf_content: "raw-jpeg-bytes")

    # pdftoppm must never be invoked for an image -- it only understands PDFs.
    processor.expects(:convert_pdf_to_images).never
    # PDF::Reader must never see a JPEG either.
    processor.expects(:process_with_text_extraction).never

    @client.stubs(:chat).returns(
      "choices" => [ { "message" => { "content" => '{"document_type":"receipt","summary":"a receipt"}' } } ]
    )

    result = processor.process

    # Verify that an image was processed (result should be present)
    assert result.present?, "Expected processing to return a result"
    assert_equal "receipt", result.document_type, "Expected receipt document type"
  end
end
