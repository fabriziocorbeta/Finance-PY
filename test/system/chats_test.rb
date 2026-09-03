require "application_system_test_case"

class ChatsTest < ApplicationSystemTestCase
  # NOTE: login_as is deliberately NOT in setup -- every test arranges its DB
  # state FIRST and logs in afterwards.
  #
  # The chat sidebar is a lazy turbo frame (see the sidebar_chat frame in
  # layouts/application.html.erb): its content arrives via a separate,
  # asynchronous request that the login itself kicks off. sign_in only waits
  # for the dashboard's own h1, never for that frame, so it returns while the
  # frame request is still in flight. Any DB change made after logging in
  # races that request: if the server answers it before the change lands, the
  # frame is filled with the pre-change state and nothing ever re-fetches it,
  # so waiting longer cannot fix it (this is what made
  # "create chat and navigate chats sidebar" flaky, and why bumping
  # Capybara.default_max_wait_time didn't help).
  #
  # Arranging state before login removes the race entirely: no request that
  # renders the sidebar exists yet, so none can observe the old state.
  setup do
    @user = users(:family_admin)
  end

  test "sidebar shows consent if ai is disabled for user" do
    @user.update!(ai_enabled: false)
    login_as(@user)

    visit root_path

    within "#chat-container" do
      assert_selector "h3", text: "Enable AI Chats"
    end
  end

  test "sidebar shows index when enabled and chats are empty" do
    with_env_overrides OPENAI_ACCESS_TOKEN: "test-token" do
      @user.update!(ai_enabled: true)
      @user.chats.destroy_all
      login_as(@user)

      visit root_url

      within "#chat-container" do
        # Asserting on the "Chats" h1 alone would pass in BOTH branches of
        # chats/index.html.erb -- the populated list renders it too -- so it
        # stayed green even when destroy_all hadn't taken effect on what the
        # sidebar rendered. #chat-form only exists in the empty branch, so it
        # actually pins the empty state this test is named after.
        assert_selector "#chat-form"
        assert_no_selector "#new-chat"
      end
    end
  end

  test "sidebar shows last viewed chat" do
    with_env_overrides OPENAI_ACCESS_TOKEN: "test-token" do
      @user.update!(ai_enabled: true)
      chat_title = @user.chats.first.title
      login_as(@user)

      visit root_url

      click_on chat_title

      # Wait for the chat to actually load before refreshing
      within "#chat-container" do
        assert_selector "h1", text: chat_title
      end

      # Page refresh
      visit root_url

      # After page refresh, we're still on the last chat we were viewing
      within "#chat-container" do
        assert_selector "h1", text: chat_title
      end
    end
  end

  test "create chat and navigate chats sidebar" do
    with_env_overrides OPENAI_ACCESS_TOKEN: "test-token" do
      @user.chats.destroy_all
      login_as(@user)

      visit root_url

      Chat.any_instance.expects(:ask_assistant_later).once

      within "#chat-form" do
        fill_in "chat[content]", with: "Can you help with my finances?"
        find("button[type='submit']").click
      end

      assert_text "Can you help with my finances?"

      find("#chat-nav-back").click

      assert_selector "h1", text: "Chats"

      click_on @user.chats.reload.first.title

      assert_text "Can you help with my finances?"
    end
  end
end
