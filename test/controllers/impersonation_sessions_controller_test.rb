require "test_helper"

class ImpersonationSessionsControllerTest < ActionDispatch::IntegrationTest
  test "impersonation session logs all activity for auditing" do
    sign_in impersonator = users(:sure_support_staff)
    impersonated = users(:family_member)

    impersonator_session = impersonation_sessions(:in_progress)

    post join_impersonation_sessions_path, params: { impersonation_session_id: impersonator_session.id }

    assert_difference "impersonator_session.logs.count", 2 do
      get root_path
      get account_path(impersonated.accessible_accounts.first)
    end
  end

  test "super admin can request an impersonation session" do
    sign_in users(:sure_support_staff)

    assert_enqueued_emails 1 do
      post impersonation_sessions_path, params: { password: user_password_test, impersonation_session: { impersonated_id: users(:family_member).id } }
    end

    assert_equal "Request sent to user. Waiting for approval.", flash[:notice]
    assert_redirected_to root_path
  end

  test "requesting impersonation requires the super admin's password" do
    sign_in users(:sure_support_staff)

    assert_no_difference "ImpersonationSession.count" do
      post impersonation_sessions_path, params: { password: "wrong", impersonation_session: { impersonated_id: users(:family_member).id } }
    end

    assert_match "Re-authentication failed", flash[:alert]
  end

  test "an expired approved session no longer impersonates and is closed" do
    sign_in super_admin = users(:sure_support_staff)
    ims = impersonation_sessions(:in_progress)
    post join_impersonation_sessions_path, params: { impersonation_session_id: ims.id }

    ims.update_columns(approved_at: (ImpersonationSession::SESSION_TTL + 1.minute).ago)
    get root_path

    assert ims.reload.complete?
    assert_nil super_admin.sessions.order(created_at: :desc).first.active_impersonator_session
  end

  test "an expired request cannot be approved" do
    ims = ImpersonationSession.create!(
      impersonator: users(:sure_support_staff), impersonated: users(:family_member), status: "pending"
    )
    ims.update_columns(created_at: (ImpersonationSession::REQUEST_TTL + 1.minute).ago)
    sign_in ims.impersonated

    put approve_impersonation_session_path(ims)

    assert ims.reload.pending?
    assert_match "expired", flash[:alert]
  end

  test "super admin can join and leave an in progress impersonation session" do
    sign_in super_admin = users(:sure_support_staff)

    impersonator_session = impersonation_sessions(:in_progress)

    super_admin_session = super_admin.sessions.order(created_at: :desc).first

    assert_nil super_admin_session.active_impersonator_session

    # Joining the session
    post join_impersonation_sessions_path, params: { impersonation_session_id: impersonator_session.id }
    assert_equal impersonator_session, super_admin_session.reload.active_impersonator_session
    assert_equal "Joined session", flash[:notice]
    assert_redirected_to root_path

    follow_redirect!

    # Leaving the session
    delete leave_impersonation_sessions_path
    assert_nil super_admin_session.reload.active_impersonator_session
    assert_equal "Left session", flash[:notice]
    assert_redirected_to root_path

    # Impersonation session still in progress because nobody has ended it yet
    assert_equal "in_progress", impersonator_session.reload.status
  end

  test "super admin can complete an impersonation session" do
    sign_in super_admin = users(:sure_support_staff)

    impersonator_session = impersonation_sessions(:in_progress)

    put complete_impersonation_session_path(impersonator_session)

    assert_equal "Session completed", flash[:notice]
    assert_nil super_admin.sessions.order(created_at: :desc).first.active_impersonator_session
    assert_equal "complete", impersonator_session.reload.status
    assert_redirected_to root_path
  end

  test "regular user can complete an impersonation session" do
    sign_in regular_user = users(:family_member)

    impersonator_session = impersonation_sessions(:in_progress)

    put complete_impersonation_session_path(impersonator_session)

    assert_equal "Session completed", flash[:notice]
    assert_equal "complete", impersonator_session.reload.status
    assert_redirected_to root_path
  end

  test "super admin cannot accept an impersonation session" do
    sign_in super_admin = users(:sure_support_staff)

    impersonator_session = impersonation_sessions(:in_progress)

    put approve_impersonation_session_path(impersonator_session)

    assert_response :not_found
  end

  test "regular user can accept an impersonation session" do
    sign_in regular_user = users(:family_member)

    impersonator_session = impersonation_sessions(:in_progress)

    put approve_impersonation_session_path(impersonator_session)

    assert_equal "Request approved", flash[:notice]
    assert_equal "in_progress", impersonator_session.reload.status
    assert_redirected_to root_path
  end

  test "regular user can reject an impersonation session" do
    sign_in regular_user = users(:family_member)

    impersonator_session = impersonation_sessions(:in_progress)

    put reject_impersonation_session_path(impersonator_session)

    assert_equal "Request rejected", flash[:notice]
    assert_equal "rejected", impersonator_session.reload.status
    assert_redirected_to root_path
  end
end
