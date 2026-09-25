require "test_helper"

class Provider::Openai::Concerns::LangfuseSanitizerTest < ActiveSupport::TestCase
  class Dummy
    include Provider::Openai::Concerns::LangfuseSanitizer
    public :sanitize_for_langfuse, :langfuse_redact_content?
  end

  setup do
    @dummy = Dummy.new
  end

  test "does not redact outside production" do
    Rails.env.stubs(:production?).returns(false)

    payload = { transactions: [ { description: "Whole Foods Market" } ] }
    assert_equal payload, @dummy.sanitize_for_langfuse(payload)
  end

  test "redacts financial content in production by default" do
    Rails.env.stubs(:production?).returns(true)
    ENV.stubs(:[]).with("LANGFUSE_ALLOW_FULL_CONTENT").returns(nil)

    payload = {
      model: "gpt-4.1",
      transactions: [ { description: "Whole Foods Market", amount: "-42.50" } ],
      note: "some free text note"
    }

    sanitized = @dummy.sanitize_for_langfuse(payload)

    # Shape-only placeholders, never the real strings/arrays.
    assert_equal({ redacted: true, length: "gpt-4.1".length }, sanitized[:model])
    assert_equal({ redacted: true, count: 1 }, sanitized[:transactions])
    assert_equal({ redacted: true, length: "some free text note".length }, sanitized[:note])

    sanitized_json = sanitized.to_s
    assert_not sanitized_json.include?("Whole Foods Market")
    assert_not sanitized_json.include?("-42.50")
    assert_not sanitized_json.include?("some free text note")
  end

  test "LANGFUSE_ALLOW_FULL_CONTENT=true opts back into full content in production" do
    Rails.env.stubs(:production?).returns(true)
    ENV.stubs(:[]).with("LANGFUSE_ALLOW_FULL_CONTENT").returns("true")

    payload = { transactions: [ { description: "Whole Foods Market" } ] }
    assert_equal payload, @dummy.sanitize_for_langfuse(payload)
  end
end
