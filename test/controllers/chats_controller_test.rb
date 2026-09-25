require "test_helper"

class ChatsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:family_admin)
    @family = families(:dylan_family)
    sign_in @user
  end

  test "gets index" do
    get chats_url
    assert_response :success
  end

  test "creates chat" do
    assert_difference("Chat.count") do
      post chats_url, params: { chat: { content: "Hello", ai_model: "gpt-4.1" } }
    end

    assert_redirected_to chat_path(Chat.order(created_at: :desc).first, thinking: true)
  end

  test "creates chat with an invalid model surfaces the specific validation error, not a generic one" do
    assert_no_difference("Chat.count") do
      post chats_url, params: { chat: { content: "Hello", ai_model: "totally-bogus-model" } }
    end

    assert_redirected_to new_chat_path
    assert_equal I18n.t("chats.errors.invalid_model"), flash[:alert]
  end

  test "shows chat" do
    get chat_url(chats(:one))
    assert_response :success
  end

  # E5 corrector round 1: same LLM-quota bypass as the API retry endpoint
  # (retry_last_message! re-asks off the existing last UserMessage instead of
  # creating a new one, so UserMessage#llm_quota_available never runs).
  test "refuses to retry once the family's daily LLM token quota is used up" do
    chat = chats(:one)
    chat.messages.create!(type: "UserMessage", content: "Hello", ai_model: "gpt-4.1")
    # ChatsController#retry operates on @chat, which (pre-existing behavior,
    # unrelated to this fix -- `set_chat` doesn't run for :retry) is actually
    # @last_viewed_chat from ApplicationController, not params[:id]. Visiting
    # the chat first, as the real UI always does before offering a retry
    # button, sets that.
    get chat_url(chat)
    LlmUsage.create!(
      family: @family,
      provider: "openai",
      model: "gpt-4.1",
      operation: "chat_response",
      prompt_tokens: UsageQuota::DAILY_LLM_TOKEN_LIMIT,
      completion_tokens: 0,
      total_tokens: UsageQuota::DAILY_LLM_TOKEN_LIMIT
    )

    assert_no_enqueued_jobs only: AssistantResponseJob do
      post retry_chat_url(chat)
    end

    assert_redirected_to chat_path(chat)
    assert_equal I18n.t("chats.errors.llm_quota_exceeded"), flash[:alert]
  end

  test "destroys chat" do
    assert_difference("Chat.count", -1) do
      delete chat_url(chats(:one))
    end

    assert_redirected_to chats_url
  end

  test "should not allow access to other user's chats" do
    other_user = users(:family_member)
    other_chat = Chat.create!(user: other_user, title: "Other User's Chat")

    get chat_url(other_chat)
    assert_response :not_found

    delete chat_url(other_chat)
    assert_response :not_found
  end
end
