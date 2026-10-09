require "test_helper"

class Admin::DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:sure_support_staff)
  end

  test "index counts families across the whole platform, not just the admin's own" do
    # users(:sure_support_staff) belongs to the "empty" family; users(:family_admin)
    # belongs to "dylan_family" -- a different one. Every admin query here is
    # cross-family by nature (platform-wide usage), so without
    # RlsContext.with_auth_bypass (FORCE RLS on families/users/sessions/chats/
    # messages) this count would silently only include the admin's own family,
    # and the real Family.count/User.count (queried directly, outside any
    # request-scoped RLS context) would be greater than what the page shows.
    assert_operator Family.count, :>=, 2

    get admin_root_url
    assert_response :success

    assert_match Family.count.to_s, response.body
    assert_match User.count.to_s, response.body
  end

  test "index includes chat usage from a family other than the admin's own" do
    other_user = users(:family_admin)
    chat = Chat.create!(user: other_user, title: "Test chat")
    UserMessage.create!(chat: chat, content: "Hello", ai_model: "gpt-4.1")

    get admin_root_url
    assert_response :success

    # The page must show at least 1 chat -- if RLS silently scoped this to
    # the admin's own family (which has no chats of its own), the stat card
    # would render "0" instead.
    doc = Nokogiri::HTML(response.body)
    label = doc.css("p").find { |p| p.text.strip == I18n.t("admin.dashboard.index.total_chats") }
    total_chats_value = label&.parent&.parent&.css("p.text-2xl")&.first&.text
    assert_not_equal "0", total_chats_value
  end

  test "non-super-admin is redirected" do
    sign_in users(:family_admin)

    get admin_root_url
    assert_redirected_to root_path
  end

  test "index renders a 30-day signup bar chart that reflects a family other than the admin's own" do
    # dylan_family (owned by users(:family_admin), a different family than
    # the signed-in admin's own "empty" family) was created by fixtures in
    # the past, so it won't show in a *new* 30-day signup, but a freshly
    # created family here will -- proving the chart isn't scoped to the
    # admin's own family, which created nothing today.
    Family.create!(name: "Cross-family signup test")

    get admin_root_url
    assert_response :success

    doc = Nokogiri::HTML(response.body)
    rects = doc.css("svg#admin-signup-chart rect")
    assert_equal 30, rects.size
    total_height = rects.sum { |r| r["height"].to_f }
    assert_operator total_height, :>, 0
  end

  test "index links recent families to their admin show page" do
    family = families(:dylan_family)

    get admin_root_url
    assert_response :success
    assert_select "a[href=?]", admin_family_path(family)
  end
end
