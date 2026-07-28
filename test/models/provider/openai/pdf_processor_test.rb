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

    captured = nil
    @client.expects(:chat).with { |**kwargs| captured = kwargs[:parameters]; true }.returns(
      "choices" => [ { "message" => { "content" => '{"document_type":"receipt","summary":"a receipt"}' } } ]
    )

    result = processor.process

    assert result.present?, "Expected processing to return a result"
    assert_equal "receipt", result.document_type, "Expected receipt document type"

    image_part = captured[:messages].last[:content].find { |c| c[:type] == "image_url" }
    assert image_part.present?, "expected an image_url part in the vision request"
    assert image_part[:image_url][:url].start_with?("data:image/jpeg;base64,"),
      "expected the real content type in the data URL, got: #{image_part[:image_url][:url][0..40]}"
    assert_equal Provider::Openai::VISION_MODEL, captured[:model]
  end
end
