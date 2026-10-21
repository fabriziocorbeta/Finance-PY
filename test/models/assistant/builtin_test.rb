require "test_helper"

class Assistant::BuiltinTest < ActiveSupport::TestCase
  include ProviderTestHelper

  FALLBACKS = "openai/gpt-oss-20b,google/gemma-4-31b-it".freeze

  setup do
    @chat = chats(:two)
    @message = @chat.messages.create!(type: "UserMessage", content: "¿Cuánto gasté este mes?", ai_model: "gpt-4.1")
    @assistant_message = @chat.messages.where(type: "AssistantMessage", status: "pending").order(:created_at).last
    @assistant = Assistant.for_chat(@chat)
    Assistant::ModelFallback.any_instance.stubs(:wait)
  end

  test "busy primary is retried once, then the fallback model answers and is recorded" do
    Assistant::ModelFallback.any_instance.expects(:wait).with(Assistant::ModelFallback::BUSY_RETRY_DELAY).once

    primary = provider_for("gpt-4.1")
    primary.expects(:chat_response).twice.returns(provider_error_response(busy_error))

    fallback = provider_for("openai/gpt-oss-20b")
    expect_answer(fallback, model: "openai/gpt-oss-20b", text: "Gastaste ₲ 1.250.000")

    with_env_overrides("OPENAI_FALLBACK_MODELS" => FALLBACKS) do
      @assistant.respond_to(@message, assistant_message: @assistant_message)
    end

    answer = @assistant_message.reload
    assert_equal "Gastaste ₲ 1.250.000", answer.content
    assert_equal "openai/gpt-oss-20b", answer.ai_model
    assert answer.complete?
    assert_nil @chat.reload.error
  end

  test "a primary that times out hands over to the next model without a same-model retry" do
    Assistant::ModelFallback.any_instance.expects(:wait).never

    primary = provider_for("gpt-4.1")
    primary.expects(:with_request_timeout).with(Assistant::ModelFallback::DEFAULT_ATTEMPT_TIMEOUT).returns(primary)
    primary.expects(:chat_response).once.returns(provider_error_response(timeout_error))

    # Last model in the chain keeps the full OPENAI_REQUEST_TIMEOUT.
    last = provider_for("openai/gpt-oss-20b")
    last.expects(:with_request_timeout).never
    expect_answer(last, model: "openai/gpt-oss-20b", text: "Listo")

    # compose passes unset vars as "", which must mean "use the default".
    with_env_overrides("OPENAI_FALLBACK_MODELS" => "openai/gpt-oss-20b", "OPENAI_CHAT_ATTEMPT_TIMEOUT" => "") do
      @assistant.respond_to(@message, assistant_message: @assistant_message)
    end

    assert_equal "openai/gpt-oss-20b", @assistant_message.reload.ai_model
    assert_equal "Listo", @assistant_message.content
  end

  test "a non-retryable error fails fast without trying the fallback" do
    unauthorized = Provider::Openai::Error.new("the server responded with status 401", http_status: 401)

    primary = provider_for("gpt-4.1")
    primary.expects(:chat_response).once.returns(provider_error_response(unauthorized))
    @assistant.expects(:get_model_provider).with("openai/gpt-oss-20b").never

    @chat.expects(:add_error).with(unauthorized).once

    with_env_overrides("OPENAI_FALLBACK_MODELS" => FALLBACKS) do
      @assistant.respond_to(@message, assistant_message: @assistant_message)
    end

    assert_not AssistantMessage.exists?(@assistant_message.id)
  end

  test "when every model is busy the chat shows the friendly busy message" do
    [ "gpt-4.1", "openai/gpt-oss-20b", "google/gemma-4-31b-it" ].each do |model|
      provider_for(model).expects(:chat_response).twice.returns(provider_error_response(busy_error))
    end

    with_env_overrides("OPENAI_FALLBACK_MODELS" => FALLBACKS) do
      @assistant.respond_to(@message, assistant_message: @assistant_message)
    end

    @chat.reload
    assert_equal I18n.t("chat.errors.busy"), @chat.presentable_error_message
    assert_includes @chat.technical_error_message, "HTTP 503"
    assert_not AssistantMessage.exists?(@assistant_message.id)
  end

  test "without fallback models a busy provider still gets one retry before the busy message" do
    provider_for("gpt-4.1").expects(:chat_response).twice.returns(provider_error_response(busy_error))

    with_env_overrides("OPENAI_FALLBACK_MODELS" => nil) do
      @assistant.respond_to(@message, assistant_message: @assistant_message)
    end

    assert_equal I18n.t("chat.errors.busy"), @chat.reload.presentable_error_message
  end

  test "a model that already streamed text is not answered over by a fallback" do
    primary = provider_for("gpt-4.1")
    primary.expects(:chat_response).with do |_prompt, **options|
      options[:streamer].call(text_chunk("Gastaste "))
      true
    end.returns(provider_error_response(busy_error))
    @assistant.expects(:get_model_provider).with("openai/gpt-oss-20b").never

    with_env_overrides("OPENAI_FALLBACK_MODELS" => FALLBACKS) do
      @assistant.respond_to(@message, assistant_message: @assistant_message)
    end

    partial = @assistant_message.reload
    assert partial.failed?
    assert_equal "Gastaste ", partial.content
    assert_equal "gpt-4.1", partial.ai_model
  end

  private

    def provider_for(model)
      provider = mock("provider #{model}")
      provider.stubs(:with_request_timeout).returns(provider)
      @assistant.stubs(:get_model_provider).with(model).returns(provider)
      provider
    end

    def expect_answer(provider, model:, text:)
      chunk = response_chunk(text)
      provider.expects(:chat_response).with do |_prompt, **options|
        assert_equal model, options[:model]
        options[:streamer].call(text_chunk(text))
        options[:streamer].call(chunk)
        true
      end.returns(provider_success_response(chunk.data))
    end

    def busy_error
      Provider::Openai::Error.new("the server responded with status 503", http_status: 503)
    end

    def timeout_error
      Provider::Openai::Error.new("Net::ReadTimeout", transport_failure: :timeout)
    end

    def text_chunk(text)
      Provider::LlmConcept::ChatStreamChunk.new(type: "output_text", data: text, usage: nil)
    end

    def response_chunk(text)
      Provider::LlmConcept::ChatStreamChunk.new(
        type: "response",
        data: Provider::LlmConcept::ChatResponse.new(
          id: "resp_1",
          model: "test",
          messages: [ Provider::LlmConcept::ChatMessage.new(id: "msg_1", output_text: text) ],
          function_requests: []
        ),
        usage: nil
      )
    end
end
