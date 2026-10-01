require "test_helper"
require_relative "row_level_security_test"

# Regression test for the invitations table's own accept-by-token flow under
# real FORCE ROW LEVEL SECURITY -- InvitationsControllerTest already covers
# this functionally (accept/confirm_accept), but those tests run under the
# default superuser-owning DB role, which bypasses RLS entirely regardless
# of policy content. That gap is exactly what let the invitations table's
# bypass-less policy (20260923143230) go unnoticed once it was put under
# FORCE (20260928170000): every real invitation link has 404'd since then.
# See AllowAuthBypassForInvitationsRls (20261001192000) and the matching
# RlsContext.with_auth_bypass wraps in InvitationsController#accept /
# #confirm_accept.
class RowLevelSecurityInvitationsTest < ActionDispatch::IntegrationTest
  test "invitations has FORCE ROW LEVEL SECURITY set" do
    forced = ActiveRecord::Base.connection.select_value(<<~SQL)
      SELECT relforcerowsecurity FROM pg_class WHERE relname = 'invitations'
    SQL
    assert_equal true, forced, "Expected invitations to have FORCE ROW LEVEL SECURITY set"
  end

  test "the public accept link finds a real invitation under app_user with real FORCE RLS" do
    family = families(:dylan_family)
    admin = users(:family_admin)
    invitation = Invitation.create!(
      email: "rls-invite-test@example.com",
      role: "member",
      inviter: admin,
      family: family
    )

    RowLevelSecurityTest.ensure_non_superuser_role
    ActiveRecord::Base.connection.execute("SET ROLE app_user")

    get accept_invitation_url(invitation.token)
    assert_response :success, "A real, pending invitation's own accept link must not 404 under FORCE RLS"
  ensure
    ActiveRecord::Base.connection.execute("RESET ROLE") rescue nil
  end

  test "confirm_accept moves a brand-new registrant into the inviting family under app_user with real FORCE RLS" do
    family = families(:dylan_family)
    admin = users(:family_admin)
    # users(:empty) mirrors InvitationsControllerTest's own existing coverage
    # of this flow (already-onboarded, no subscription-gate redirect) -- the
    # only thing this test adds on top is running the exchange under a real
    # non-owner role with FORCE RLS actually engaged.
    invitee = users(:empty)
    invitation = Invitation.create!(
      email: invitee.email,
      role: "member",
      inviter: admin,
      family: family
    )
    sign_in(invitee)

    RowLevelSecurityTest.ensure_non_superuser_role
    ActiveRecord::Base.connection.execute("SET ROLE app_user")

    post confirm_accept_invitation_path(invitation.token)

    # Back to full visibility to inspect the result -- the request itself
    # ran under app_user above, which is what matters; these reloads are
    # just the test checking what really landed in the database.
    ActiveRecord::Base.connection.execute("RESET ROLE")

    invitation.reload
    invitee.reload
    assert invitation.accepted_at.present?, "Invitation should be marked accepted -- the whole exchange must have actually run under app_user"
    assert_equal family.id, invitee.family_id, "Invitee should now belong to the inviting family"
  ensure
    ActiveRecord::Base.connection.execute("RESET ROLE") rescue nil
  end
end
