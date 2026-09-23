require "test_helper"

class UserMessageTest < ActiveSupport::TestCase
  setup do
    @chat = chats(:one)
  end

  test "requests assistant response after creation" do
    @chat.expects(:ask_assistant_later).once

    message = UserMessage.create!(chat: @chat, content: "Hello from user", ai_model: "gpt-4.1")
    message.update!(content: "updated")

    streams = capture_turbo_stream_broadcasts(@chat)
    assert_equal 2, streams.size
    assert_equal "append", streams.first["action"]
    assert_equal @chat.messages_target, streams.first["target"]
    assert_equal "update", streams.last["action"]
    assert_equal "user_message_#{message.id}", streams.last["target"]
  end

  test "rejects an ai_model outside the allowlist" do
    message = UserMessage.new(chat: @chat, content: "Hello", ai_model: "some-arbitrary-model")

    assert_not message.valid?
    assert_includes message.errors[:base], I18n.t("chats.errors.invalid_model")
  end

  test "allows the family's default model and first-party OpenAI model prefixes" do
    assert UserMessage.new(chat: @chat, content: "Hello", ai_model: Chat.default_model).valid?
    assert UserMessage.new(chat: @chat, content: "Hello", ai_model: "gpt-5-mini").valid?
  end

  test "rejects content over the max length" do
    message = UserMessage.new(chat: @chat, content: "a" * (Message::MAX_CONTENT_LENGTH + 1), ai_model: "gpt-4.1")

    assert_not message.valid?
    assert_includes message.errors[:content], "is too long (maximum is #{Message::MAX_CONTENT_LENGTH} characters)"
  end

  test "rejects a new message once the family's daily LLM token quota is used up" do
    family = @chat.user.family
    LlmUsage.create!(
      family: family,
      provider: "openai",
      model: "gpt-4.1",
      operation: "chat_response",
      prompt_tokens: UsageQuota::DAILY_LLM_TOKEN_LIMIT,
      completion_tokens: 0,
      total_tokens: UsageQuota::DAILY_LLM_TOKEN_LIMIT
    )

    message = UserMessage.new(chat: @chat, content: "Hello", ai_model: "gpt-4.1")

    assert_not message.valid?
    assert_includes message.errors[:base], I18n.t("chats.errors.llm_quota_exceeded")
  end

  test "allows a new message when the family is under its daily LLM token quota" do
    family = @chat.user.family
    LlmUsage.create!(
      family: family,
      provider: "openai",
      model: "gpt-4.1",
      operation: "chat_response",
      prompt_tokens: UsageQuota::DAILY_LLM_TOKEN_LIMIT - 1,
      completion_tokens: 0,
      total_tokens: UsageQuota::DAILY_LLM_TOKEN_LIMIT - 1
    )

    message = UserMessage.new(chat: @chat, content: "Hello", ai_model: "gpt-4.1")

    assert message.valid?
  end
end
