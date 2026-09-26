require "test_helper"

class InvitationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in @admin = users(:family_admin)
    @invitation = invitations(:one)
  end

  test "should get new" do
    get new_invitation_url
    assert_response :success
    assert_select "option[value=?]", "member"
    assert_select "option[value=?]", "admin"
  end

  test "should create invitation for member" do
    Rails.application.config.stubs(:app_mode).returns("managed".inquiry)

    assert_difference("Invitation.count") do
      assert_enqueued_with(job: ActionMailer::MailDeliveryJob) do
        post invitations_url, params: {
          invitation: {
            email: "new@example.com",
            role: "member"
          }
        }
      end
    end

    invitation = Invitation.order(created_at: :desc).first
    assert_equal "member", invitation.role
    assert_equal @admin, invitation.inviter
    assert_equal "new@example.com", invitation.email
    assert_redirected_to settings_profile_path
    assert_equal I18n.t("invitations.create.success"), flash[:notice]
  end

  test "inviting an existing user does not move them until they accept explicitly" do
    existing_user = users(:empty)
    original_family_id = existing_user.family_id
    assert original_family_id != @admin.family_id

    assert_difference("Invitation.count") do
      assert_enqueued_with(job: ActionMailer::MailDeliveryJob) do
        post invitations_url, params: {
          invitation: {
            email: existing_user.email,
            role: "member"
          }
        }
      end
    end

    invitation = Invitation.order(created_at: :desc).first
    assert invitation.pending?, "Invitation should remain pending, not auto-accepted"
    assert_nil invitation.accepted_at

    existing_user.reload
    assert_equal original_family_id, existing_user.family_id, "Admin sending an invitation must never move the invitee's family by itself"
    assert_redirected_to settings_profile_path
    assert_equal I18n.t("invitations.create.success"), flash[:notice]

    # Only the invitee, acting on their own behalf, can accept and move themselves.
    sign_in existing_user
    post confirm_accept_invitation_path(invitation.token)

    invitation.reload
    existing_user.reload
    assert invitation.accepted_at.present?
    assert_equal @admin.family_id, existing_user.family_id
    assert_equal "member", existing_user.role
  end

  test "non-admin cannot create invitations" do
    sign_in users(:family_member)

    assert_no_difference("Invitation.count") do
      post invitations_url, params: {
        invitation: {
          email: "new@example.com",
          role: "admin"
        }
      }
    end

    assert_redirected_to settings_profile_path
    assert_equal I18n.t("invitations.create.failure"), flash[:alert]
  end

  test "admin can create admin invitation" do
    assert_difference("Invitation.count") do
      post invitations_url, params: {
        invitation: {
          email: "new@example.com",
          role: "admin"
        }
      }
    end

    invitation = Invitation.order(created_at: :desc).first
    assert_equal "admin", invitation.role
    assert_equal @admin.family, invitation.family
    assert_equal @admin, invitation.inviter
  end

  test "admin can create guest invitation" do
    assert_difference("Invitation.count") do
      post invitations_url, params: {
        invitation: {
          email: "intro-invite@example.com",
          role: "guest"
        }
      }
    end

    invitation = Invitation.order(created_at: :desc).first
    assert_equal "guest", invitation.role
    assert_equal @admin.family, invitation.family
    assert_equal @admin, invitation.inviter
  end

  test "inviting an existing user as guest does not touch them until accepted, then applies intro defaults" do
    # @admin's family (dylan_family) already has an active ai_processing
    # consent (test/fixtures/consents.yml) from a different member -- revoke
    # it so this test can pin that the layout-driven ai_enabled default does
    # NOT itself grant AI access to the newly-invited guest once they join.
    Consent.where(family: @admin.family, kind: "ai_processing").active.update_all(revoked_at: Time.current)

    existing_user = users(:empty)
    existing_user.update!(
      role: :member,
      ui_layout: :dashboard,
      show_sidebar: true,
      show_ai_sidebar: true,
      ai_enabled: false
    )

    assert_difference("Invitation.count") do
      post invitations_url, params: {
        invitation: {
          email: existing_user.email,
          role: "guest"
        }
      }
    end

    # Sending the invitation alone must not change the invitee's role or UI defaults.
    existing_user.reload
    assert_equal "member", existing_user.role
    assert_not existing_user.ui_layout_intro?

    invitation = Invitation.order(created_at: :desc).first
    sign_in existing_user
    post confirm_accept_invitation_path(invitation.token)

    existing_user.reload
    assert_equal "guest", existing_user.role
    assert existing_user.ui_layout_intro?
    assert_not existing_user.show_sidebar?
    assert_not existing_user.show_ai_sidebar?
    # The preference alone does not grant AI access (E6): consent is separate.
    assert existing_user.ai_enabled
    assert_not existing_user.ai_enabled?
  end

  test "should handle invalid invitation creation" do
    assert_no_difference("Invitation.count") do
      post invitations_url, params: {
        invitation: {
          email: "",
          role: "member"
        }
      }
    end

    assert_redirected_to settings_profile_path
    assert_equal I18n.t("invitations.create.failure"), flash[:alert]
  end

  test "should accept invitation and show choice between sign in and create account" do
    get accept_invitation_url(@invitation.token)
    assert_response :success
    assert_select "a[href=?]", new_registration_path(invitation: @invitation.token), text: /Create new account/i
    assert_select "a[href=?]", new_session_path(invitation: @invitation.token), text: /already have an account/i
  end

  test "should not accept invalid invitation token" do
    get accept_invitation_url("invalid-token")
    assert_response :not_found
  end

  test "admin can remove pending invitation" do
    assert_difference("Invitation.count", -1) do
      delete invitation_url(@invitation)
    end

    assert_redirected_to settings_profile_path
    assert_equal I18n.t("invitations.destroy.success"), flash[:notice]
  end

  test "non-admin cannot remove invitations" do
    sign_in users(:family_member)

    assert_no_difference("Invitation.count") do
      delete invitation_url(@invitation)
    end

    assert_redirected_to settings_profile_path
    assert_equal I18n.t("invitations.destroy.not_authorized"), flash[:alert]
  end

  test "should handle invalid invitation removal" do
    delete invitation_url(id: "invalid-id")
    assert_response :not_found
  end
end
