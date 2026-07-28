require "test_helper"

class Provider::Openai::ReceiptExtractorTest < ActiveSupport::TestCase
  setup do
    @client = mock("openai_client")
  end

  def build_extractor
    Provider::Openai::ReceiptExtractor.new(
      client: @client,
      image_content: "fake-image-bytes",
      content_type: "image/jpeg",
      model: "test-vision-model"
    )
  end

  def stub_response(content)
    @client.expects(:chat).returns(
      "choices" => [ { "message" => { "content" => content } } ]
    )
  end

  test "extracts a single negative transaction from a receipt" do
    stub_response('{"merchant":"KALON CAFE","date":"2026-07-02","amount":55000}')

    result = build_extractor.extract

    assert_equal 1, result[:transactions].size
    txn = result[:transactions].first
    assert_equal "KALON CAFE", txn[:name]
    assert_equal "2026-07-02", txn[:date]
    assert_equal(-55000.0, txn[:amount])
  end

  test "forces the amount negative even when the model returns a positive number" do
    stub_response('{"merchant":"X","date":"2026-07-02","amount":1000}')

    assert_equal(-1000.0, build_extractor.extract[:transactions].first[:amount])
  end

  test "reads a PYG amount returned as a dot-separated string" do
    stub_response('{"merchant":"X","date":"2026-07-02","amount":"295.480"}')

    assert_equal(-295480.0, build_extractor.extract[:transactions].first[:amount])
  end

  test "returns no transactions when the model returns unusable JSON" do
    stub_response("this is not JSON at all")

    assert_equal [], build_extractor.extract[:transactions]
  end

  test "returns no transactions when the amount is missing" do
    stub_response('{"merchant":"X","date":"2026-07-02"}')

    assert_equal [], build_extractor.extract[:transactions]
  end

  test "sends the image with its real content type to the vision model" do
    captured = nil
    @client.expects(:chat).with { |params| captured = params; true }.returns(
      "choices" => [ { "message" => { "content" => '{"merchant":"X","date":"2026-07-02","amount":1}' } } ]
    )

    build_extractor.extract

    # client.chat(parameters: {...}) is called with a single keyword arg, so
    # Mocha's block matcher receives {parameters: {...}}, not the inner hash
    # directly -- confirmed empirically (captured[:messages] alone is nil).
    image_part = captured[:parameters][:messages].last[:content].find { |c| c[:type] == "image_url" }
    assert image_part[:image_url][:url].start_with?("data:image/jpeg;base64,")
  end
end
