require "test_helper"

class Admin::FamiliesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:sure_support_staff)
  end

  test "index lists families" do
    get admin_families_url
    assert_response :success
    assert_includes response.body, families(:dylan_family).name
  end

  test "update toggles business_mode_enabled" do
    family = families(:dylan_family)
    assert_not family.business_mode_enabled?

    patch admin_family_url(family), params: { family: { business_mode_enabled: true } }

    assert_redirected_to admin_families_url
    assert family.reload.business_mode_enabled?
  end

  test "non-super-admin is redirected" do
    sign_in users(:family_admin)

    get admin_families_url

    assert_redirected_to root_path
  end

  test "show renders a family's members and usage across a family other than the admin's own" do
    # users(:sure_support_staff) (the signed-in admin) belongs to the "empty"
    # family; dylan_family belongs to users(:family_admin), a different
    # family entirely. Without Admin::BaseController's RLS auth bypass, this
    # cross-family read would be silently empty.
    other_user = users(:family_admin)
    family = families(:dylan_family)
    chat = Chat.create!(user: other_user, title: "Test chat")
    UserMessage.create!(chat: chat, content: "Hello", ai_model: "gpt-4.1")

    get admin_family_url(family)

    assert_response :success
    assert_includes response.body, other_user.email
    assert_includes response.body, family.name
  end

  test "export returns a CSV covering families other than the admin's own" do
    get export_admin_families_url

    assert_response :success
    assert_equal "text/csv", response.media_type
    assert_includes response.body, families(:dylan_family).name
  end
end
