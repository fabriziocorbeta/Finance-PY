require "test_helper"

class Assistant::Function::AnalyzeInvoiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:family_admin)
    @family = @user.family
    @fn = Assistant::Function::AnalyzeInvoice.new(@user)
  end

  test "returns error for invalid source_type" do
    result = @fn.call("source_type" => "unknown")

    assert_equal false, result[:success]
    assert_equal "invalid_source_type", result[:error]
  end

  test "returns attachment_not_found when no message has an attachment" do
    result = @fn.call("source_type" => "message")

    assert_equal false, result[:success]
    assert_equal "attachment_not_found", result[:error]
  end

  test "analyzes attached invoice on user message and returns untrusted invoice data with categories" do
    chat = @user.chats.create!(title: "Invoice test")
    message = UserMessage.new(chat: chat, content: "Analiza esta factura", ai_model: Chat.default_model)
    message.attachment.attach(
      io: StringIO.new("fake-image-bytes"),
      filename: "factura.jpg",
      content_type: "image/jpeg"
    )
    message.save!(validate: false)

    @family.categories.create!(name: "Supermercados InvoiceTest", color: "#407706", lucide_icon: "shopping-bag")

    fake_provider = Object.new
    fake_provider.define_singleton_method(:analyze_invoice) do |**|
      Provider::Response.new(
        data: {
          merchant: "Supermercado Stock",
          date: "2026-03-15",
          amount: 150000.0,
          currency: "PYG",
          invoice_number: "001-001-0001",
          tax_id: "80012345-6",
          line_items: [ { description: "Pan", quantity: 1.0, unit_price: 15000.0, total: 15000.0 } ],
          payment_method: "card",
          direction: "expense",
          summary: "Groceries purchase"
        }
      )
    end

    Provider::Registry.stub(:get_provider, fake_provider) do
      UsageQuota.stub(:llm_quota_exceeded?, false) do
        result = @fn.call("source_type" => "message", "source_id" => message.id.to_s)

        assert_equal true, result[:success]
        assert_equal "message", result.dig(:source, :type)
        assert_equal message.id, result.dig(:source, :id)
        assert_equal "factura.jpg", result.dig(:source, :filename)
        assert_match(/<UNTRUSTED_DATA_/, result[:invoice_data])
        assert_includes result[:invoice_data], "Supermercado Stock"
        assert result[:categories].any? { |c| c[:name] == "Supermercados InvoiceTest" }
        assert result[:suggested_new_category_icon].present?
        assert result[:proposal_instructions].present?
      end
    end
  end
end
