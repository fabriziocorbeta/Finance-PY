# frozen_string_literal: true

require "test_helper"

class Api::V1::ChatsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:family_admin)
    @user.update!(ai_enabled: true)

    @oauth_app = Doorkeeper::Application.create!(
      name: "Test API App",
      redirect_uri: "https://example.com/callback",
      scopes: "read write read_write"
    )

    @read_token = Doorkeeper::AccessToken.create!(
      application: @oauth_app,
      resource_owner_id: @user.id,
      scopes: "read"
    )

    @write_token = Doorkeeper::AccessToken.create!(
      application: @oauth_app,
      resource_owner_id: @user.id,
      scopes: "read_write"
    )

    @chat = chats(:one)
  end

  test "should require authentication" do
    get "/api/v1/chats"
    assert_response :unauthorized
  end

  test "should require AI to be enabled" do
    @user.update!(ai_enabled: false)

    get "/api/v1/chats", headers: bearer_auth_header(@read_token)
    assert_response :forbidden

    response_body = JSON.parse(response.body)
    assert_equal "feature_disabled", response_body["error"]
  end

  test "should list chats with read scope" do
    get "/api/v1/chats", headers: bearer_auth_header(@read_token)
    assert_response :success

    response_body = JSON.parse(response.body)
    assert response_body["chats"].is_a?(Array)
    assert response_body["pagination"].present?
  end

  test "should show chat with messages" do
    get "/api/v1/chats/#{@chat.id}", headers: bearer_auth_header(@read_token)
    assert_response :success

    response_body = JSON.parse(response.body)
    assert_equal @chat.id, response_body["id"]
    assert response_body["messages"].is_a?(Array)
  end

  test "should create chat with write scope" do
    assert_difference "Chat.count" do
      post "/api/v1/chats",
        params: { title: "New chat", message: "Hello AI" },
        headers: bearer_auth_header(@write_token)
    end

    assert_response :created
    response_body = JSON.parse(response.body)
    assert_equal "New chat", response_body["title"]
  end

  test "should create chat with a generated title when none is given (native app's actual call shape)" do
    # AuthRepository.kt/ChatViewModel.kt always call
    # createChat(title = null, message = content, model = model) -- confirmed
    # live on a real device, every mobile "new chat" 422'd with
    # "Title no puede estar vacío" because this endpoint passed a nil title
    # straight to Chat#save instead of generating one the way web's
    # Chat.start! does.
    assert_difference "Chat.count" do
      post "/api/v1/chats",
        params: { message: "Cual es mi balance actual" },
        headers: bearer_auth_header(@write_token)
    end

    assert_response :created
    response_body = JSON.parse(response.body)
    assert_equal Chat.generate_title("Cual es mi balance actual"), response_body["title"]
    refute_empty response_body["title"]

    # show.json.jbuilder iterates @messages, which only `show` ever set --
    # this action saved @message fine but never assigned @messages before
    # rendering the same template, so every native "new chat" response came
    # back with "messages": [] even though the first message had actually
    # saved. Confirmed live on a real device: chat created with the right
    # title, message persisted in the DB, chat screen stayed empty.
    # (Not asserting an exact count: UserMessage's after_create_commit can
    # enqueue the assistant reply synchronously depending on the job
    # adapter, so a second message may already be present here.)
    refute_empty response_body["messages"]
    assert response_body["messages"].any? { |m| m["content"] == "Cual es mi balance actual" },
      "expected the just-sent user message to be in the response, got: #{response_body["messages"].inspect}"
  end

  test "should not create chat with read scope" do
    post "/api/v1/chats",
      params: { title: "New chat" },
      headers: bearer_auth_header(@read_token)

    assert_response :forbidden
  end

  test "should update chat" do
    patch "/api/v1/chats/#{@chat.id}",
      params: { title: "Updated title" },
      headers: bearer_auth_header(@write_token)

    assert_response :success
    response_body = JSON.parse(response.body)
    assert_equal "Updated title", response_body["title"]
  end

  test "should delete chat" do
    assert_difference "Chat.count", -1 do
      delete "/api/v1/chats/#{@chat.id}", headers: bearer_auth_header(@write_token)
    end

    assert_response :no_content
  end

  test "should not access other user's chat" do
    other_user = users(:family_member)
    other_user.update!(family: families(:empty))
    other_chat = chats(:two)
    other_chat.update!(user: other_user)

    get "/api/v1/chats/#{other_chat.id}", headers: bearer_auth_header(@read_token)
    assert_response :not_found
  end

  test "should support API key authentication" do
    # Remove any existing API keys for this user
    @user.api_keys.destroy_all

    plain_key = ApiKey.generate_secure_key
    api_key = @user.api_keys.build(
      name: "Test API Key",
      scopes: [ "read_write" ]
    )
    api_key.key = plain_key
    api_key.save!

    get "/api/v1/chats", headers: { "X-Api-Key" => plain_key }
    assert_response :success
  end

  private

    def bearer_auth_header(token)
      { "Authorization" => "Bearer #{token.token}" }
    end
end
