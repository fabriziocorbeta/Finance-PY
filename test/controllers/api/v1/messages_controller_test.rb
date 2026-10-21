# frozen_string_literal: true

require "test_helper"

class Api::V1::MessagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:family_admin)
    @user.update!(ai_enabled: true)

    @oauth_app = Doorkeeper::Application.create!(
      name: "Test API App",
      redirect_uri: "https://example.com/callback",
      scopes: "read write read_write"
    )

    @write_token = Doorkeeper::AccessToken.create!(
      application: @oauth_app,
      resource_owner_id: @user.id,
      scopes: "read_write"
    )

    @user.api_keys.active.destroy_all
    @api_key = ApiKey.create!(
      user: @user,
      name: "Test Read-Write Key",
      scopes: [ "read_write" ],
      source: "web",
      display_key: "test_rw_#{SecureRandom.hex(8)}"
    )

    @chat = chats(:one)
  end

  test "should require authentication" do
    post "/api/v1/chats/#{@chat.id}/messages"
    assert_response :unauthorized
  end

  test "should require AI to be enabled" do
    @user.update!(ai_enabled: false)

    post "/api/v1/chats/#{@chat.id}/messages",
      params: { content: "Hello" },
      headers: bearer_auth_header(@write_token)
    assert_response :forbidden
  end

  test "should create message with write scope" do
    assert_difference "UserMessage.count" do
      post "/api/v1/chats/#{@chat.id}/messages",
        params: { content: "Test message", model: "gpt-4" },
        headers: bearer_auth_header(@write_token)
    end

    assert_response :created
    response_body = JSON.parse(response.body)
    assert_equal "Test message", response_body["content"]
    assert_equal "user_message", response_body["type"]
    assert_equal "pending", response_body["ai_response_status"]
  end

  test "should enqueue assistant response job" do
    assert_enqueued_with(job: AssistantResponseJob) do
      post "/api/v1/chats/#{@chat.id}/messages",
        params: { content: "Test message" },
        headers: bearer_auth_header(@write_token)
    end
  end

  test "retry regenerates the answer to the last user message when the last turn completed" do
    user_message = messages(:chat1_user)

    post "/api/v1/chats/#{@chat.id}/messages/retry", headers: api_headers(@api_key)

    assert_response :accepted
    pending = AssistantMessage.find(JSON.parse(response.body)["message_id"])
    assert pending.pending?
    assert_equal user_message.ai_model, pending.ai_model
    assert_enqueued_with(job: AssistantResponseJob, args: [ user_message, pending ])
  end

  # The failed-turn case: Assistant::Builtin destroys the empty reply and sets
  # chat.error, leaving the user message last. This used to 422.
  test "retry after a failed turn clears the error and re-asks for the user message" do
    user_message = failed_turn!

    assert_difference "AssistantMessage.count", 1 do
      post "/api/v1/chats/#{@chat.id}/messages/retry", headers: api_headers(@api_key)
    end

    assert_response :accepted
    body = JSON.parse(response.body)
    assert_equal "Retry initiated", body["message"]
    pending = AssistantMessage.find(body["message_id"])
    assert pending.pending?
    assert_nil @chat.reload.error
    assert_enqueued_with(job: AssistantResponseJob, args: [ user_message, pending ])
  end

  test "retry after a partially streamed reply that was demoted to failed re-asks for the user message" do
    user_message = failed_turn!
    @chat.messages.create!(type: "AssistantMessage", content: "Partial", ai_model: "gpt-4.1", status: :failed)

    post "/api/v1/chats/#{@chat.id}/messages/retry", headers: api_headers(@api_key)

    assert_response :accepted
    pending = AssistantMessage.find(JSON.parse(response.body)["message_id"])
    assert_enqueued_with(job: AssistantResponseJob, args: [ user_message, pending ])
  end

  test "double-tapped retry enqueues one response and returns the same pending message" do
    failed_turn!

    assert_difference "AssistantMessage.count", 1 do
      assert_enqueued_jobs 1, only: AssistantResponseJob do
        2.times { post "/api/v1/chats/#{@chat.id}/messages/retry", headers: api_headers(@api_key) }
      end
    end

    assert_response :accepted
    assert_equal @chat.messages.where(type: "AssistantMessage", status: "pending").sole.id,
      JSON.parse(response.body)["message_id"]
  end

  test "retry replaces a pending reply whose job died long ago" do
    user_message = failed_turn!
    stale = @chat.messages.create!(type: "AssistantMessage", content: "", ai_model: "gpt-4.1", status: :pending)
    stale.update_columns(created_at: (Chat::STALE_PENDING_RESPONSE_AFTER + 1.minute).ago)

    post "/api/v1/chats/#{@chat.id}/messages/retry", headers: api_headers(@api_key)

    assert_response :accepted
    assert_not AssistantMessage.exists?(stale.id)
    pending = AssistantMessage.find(JSON.parse(response.body)["message_id"])
    assert_enqueued_with(job: AssistantResponseJob, args: [ user_message, pending ])
  end

  test "retry returns 404 for another family's chat" do
    other_user = users(:family_member)
    other_user.update!(family: families(:empty))
    other_chat = chats(:two)
    other_chat.update!(user: other_user, error: { message: "boom" }.to_json)

    assert_no_enqueued_jobs only: AssistantResponseJob do
      post "/api/v1/chats/#{other_chat.id}/messages/retry", headers: api_headers(@api_key)
    end

    assert_response :not_found
    assert_not_nil other_chat.reload.error
  end

  test "should refuse to retry once the family's daily LLM token quota is used up" do
    @chat.messages.create!(type: "AssistantMessage", content: "Previous response", ai_model: "gpt-4")
    LlmUsage.create!(
      family: @chat.user.family,
      provider: "openai",
      model: "gpt-4.1",
      operation: "chat_response",
      prompt_tokens: UsageQuota::DAILY_LLM_TOKEN_LIMIT,
      completion_tokens: 0,
      total_tokens: UsageQuota::DAILY_LLM_TOKEN_LIMIT
    )

    assert_no_enqueued_jobs only: AssistantResponseJob do
      assert_no_difference "AssistantMessage.count" do
        post "/api/v1/chats/#{@chat.id}/messages/retry",
          headers: bearer_auth_header(@write_token)
      end
    end

    assert_response :unprocessable_entity
    response_body = JSON.parse(response.body)
    assert_equal I18n.t("chats.errors.llm_quota_exceeded"), response_body["error"]
  end

  test "should not retry a chat with no user message to answer" do
    @chat.messages.destroy_all

    assert_no_enqueued_jobs only: AssistantResponseJob do
      post "/api/v1/chats/#{@chat.id}/messages/retry.json",
        headers: bearer_auth_header(@write_token)
    end

    assert_response :unprocessable_entity
    response_body = JSON.parse(response.body)
    assert_equal "No assistant message to retry", response_body["error"]
  end

  test "should not access messages in other user's chat" do
    other_user = users(:family_member)
    other_user.update!(family: families(:empty))
    other_chat = chats(:two)
    other_chat.update!(user: other_user)

    post "/api/v1/chats/#{other_chat.id}/messages",
      params: { content: "Test" },
      headers: bearer_auth_header(@write_token)

    assert_response :not_found
  end

  private

    def bearer_auth_header(token)
      { "Authorization" => "Bearer #{token.token}" }
    end

    def api_headers(api_key)
      { "X-Api-Key" => api_key.display_key }
    end

    # Leaves @chat the way Assistant::Builtin#respond_to does when the LLM call
    # fails: empty reply destroyed, user message last, chat.error set.
    def failed_turn!
      @chat.messages.where(type: "AssistantMessage").destroy_all
      @chat.update!(error: { message: "boom", technical_message: "boom", type: "StandardError" }.to_json)
      messages(:chat1_user)
    end
end
