require "test_helper"

class Provider::Openai::InvoiceAnalyzerTest < ActiveSupport::TestCase
  class FakeClient
    attr_reader :last_parameters

    def initialize(response_content)
      @response_content = response_content
    end

    def chat(parameters:)
      @last_parameters = parameters
      {
        "choices" => [
          {
            "message" => {
              "content" => @response_content
            }
          }
        ]
      }
    end
  end

  test "analyzes an image invoice with PYG amounts and line items" do
    json = {
      merchant: "Supermercado Stock",
      date: "2026-03-15",
      amount: "295.480",
      currency: "Gs.",
      invoice_number: "001-002-0004567",
      tax_id: "80012345-6",
      line_items: [
        { description: "Leche entera 1L", quantity: 2, unit_price: "7.500", total: "15.000" },
        { description: "Carne vacuna", quantity: 1, unit_price: "280.480", total: "280.480" }
      ],
      payment_method: "card",
      direction: "expense",
      summary: "Compra de supermercado"
    }.to_json

    client = FakeClient.new(json)
    analyzer = Provider::Openai::InvoiceAnalyzer.new(
      client: client,
      content: "fake-jpeg-bytes",
      content_type: "image/jpeg",
      model: Provider::Openai::VISION_MODEL,
      filename: "factura.jpg"
    )

    result = analyzer.analyze

    assert_equal "Supermercado Stock", result[:merchant]
    assert_equal "2026-03-15", result[:date]
    assert_equal 295480.0, result[:amount]
    assert_equal "PYG", result[:currency]
    assert_equal "001-002-0004567", result[:invoice_number]
    assert_equal "80012345-6", result[:tax_id]
    assert_equal "card", result[:payment_method]
    assert_equal "expense", result[:direction]
    assert_equal 2, result[:line_items].size
    assert_equal 15000.0, result[:line_items].first[:total]

    user_content = client.last_parameters[:messages].last[:content]
    assert_kind_of Array, user_content
    assert_equal "auto", user_content.first.dig(:image_url, :detail)
  end

  test "analyzes a USD invoice preserving decimal cents" do
    json = {
      merchant: "Cloud Hosting Inc",
      date: "2026-03-20",
      amount: "49.99",
      currency: "USD",
      line_items: [
        { description: "VPS Plan", quantity: 1, unit_price: "49.99", total: "49.99" }
      ],
      direction: "expense",
      summary: "Monthly cloud hosting"
    }.to_json

    client = FakeClient.new(json)
    analyzer = Provider::Openai::InvoiceAnalyzer.new(
      client: client,
      content: "fake-png-bytes",
      content_type: "image/png",
      model: Provider::Openai::VISION_MODEL
    )

    result = analyzer.analyze

    assert_equal "USD", result[:currency]
    assert_equal 49.99, result[:amount]
    assert_equal 49.99, result[:line_items].first[:total]
  end

  test "raises Provider::Openai::Error on unsupported content type" do
    client = FakeClient.new("{}")
    analyzer = Provider::Openai::InvoiceAnalyzer.new(
      client: client,
      content: "hello",
      content_type: "text/plain",
      model: "gpt-4.1"
    )

    assert_raises(Provider::Openai::Error) do
      analyzer.analyze
    end
  end
end
