require "test_helper"

class InvitationTest < ActiveSupport::TestCase
  setup do
    @invitation = invitations(:one)
    @family = @invitation.family
    @inviter = @invitation.inviter
  end

  test "accept_for adds user to family when email matches" do
    user = users(:empty)
    user.update_columns(family_id: families(:empty).id, role: "admin")
    assert user.family_id != @family.id

    invitation = @family.invitations.create!(email: user.email, role: "member", inviter: @inviter)
    assert invitation.pending?
    result = invitation.accept_for(user)

    assert result
    user.reload
    assert_equal @family.id, user.family_id
    assert_equal "member", user.role
    invitation.reload
    assert invitation.accepted_at.present?
  end

  test "accept_for returns false when user email does not match" do
    user = users(:family_member)
    assert user.email != @invitation.email

    result = @invitation.accept_for(user)

    assert_not result
    user.reload
    assert_equal families(:dylan_family).id, user.family_id
    @invitation.reload
    assert_nil @invitation.accepted_at
  end

  test "accept_for updates role when user already in family" do
    user = users(:family_member)
    user.update!(family_id: @family.id, role: "member")
    invitation = @family.invitations.create!(email: user.email, role: "admin", inviter: @inviter)
    original_family_id = user.family_id

    result = invitation.accept_for(user)

    assert result
    user.reload
    assert_equal original_family_id, user.family_id
    assert_equal "admin", user.role
    invitation.reload
    assert invitation.accepted_at.present?
  end

  test "accept_for returns false when invitation not pending" do
    @invitation.update!(accepted_at: 1.hour.ago)
    user = users(:empty)

    result = @invitation.accept_for(user)

    assert_not result
  end

  test "cannot create invitation when email has pending invitation from another family" do
    other_family = families(:empty)
    other_inviter = users(:empty)
    other_inviter.update_columns(family_id: other_family.id, role: "admin")

    email = "cross-family-test@example.com"

    # Create a pending invitation in the first family
    @family.invitations.create!(email: email, role: "member", inviter: @inviter)

    # Attempting to create a pending invitation in a different family should fail
    invitation = other_family.invitations.build(email: email, role: "member", inviter: other_inviter)
    assert_not invitation.valid?
    assert_includes invitation.errors[:email], "already has a pending invitation from another family"
  end

  test "can create invitation when existing invitation from another family is accepted" do
    other_family = families(:empty)
    other_inviter = users(:empty)
    other_inviter.update_columns(family_id: other_family.id, role: "admin")

    email = "cross-family-accepted@example.com"

    # Create an accepted invitation in the first family
    accepted_invitation = @family.invitations.create!(email: email, role: "member", inviter: @inviter)
    accepted_invitation.update!(accepted_at: Time.current)

    # Should be able to create a pending invitation in a different family
    invitation = other_family.invitations.build(email: email, role: "member", inviter: other_inviter)
    assert invitation.valid?
  end

  test "can create invitation when existing invitation from another family is expired" do
    other_family = families(:empty)
    other_inviter = users(:empty)
    other_inviter.update_columns(family_id: other_family.id, role: "admin")

    email = "cross-family-expired@example.com"

    # Create an expired invitation in the first family
    expired_invitation = @family.invitations.create!(email: email, role: "member", inviter: @inviter)
    expired_invitation.update_columns(expires_at: 1.day.ago)

    # Should be able to create a pending invitation in a different family
    invitation = other_family.invitations.build(email: email, role: "member", inviter: other_inviter)
    assert invitation.valid?
  end

  test "can create invitation in same family (uniqueness scoped to family)" do
    email = "same-family-test@example.com"

    # Create a pending invitation in the family
    @family.invitations.create!(email: email, role: "member", inviter: @inviter)

    # Attempting to create another in the same family should fail due to the existing scope validation
    invitation = @family.invitations.build(email: email, role: "admin", inviter: @inviter)
    assert_not invitation.valid?
    assert_includes invitation.errors[:email], "has already been invited to this family"
  end

  test "inviter_is_admin blocks invitation and records a visible error when inviter is not admin" do
    non_admin_inviter = users(:family_member)
    assert_not non_admin_inviter.admin?

    invitation = @family.invitations.build(email: "blocked-by-non-admin@example.com", role: "member", inviter: non_admin_inviter)

    assert_not invitation.valid?
    assert_includes invitation.errors[:base], "Inviter must be an admin to send invitations"
    assert_not invitation.save
  end

  test "cannot invite a user who already has financial data in another family" do
    other_family = families(:empty)
    other_user = users(:empty)
    other_user.update_columns(family_id: other_family.id)

    Account.create!(
      family: other_family,
      owner: other_user,
      name: "Other family checking",
      balance: 100,
      currency: "USD",
      accountable: Depository.new
    )

    invitation = @family.invitations.build(email: other_user.email, role: "member", inviter: @inviter)

    assert_not invitation.valid?
    assert_includes invitation.errors[:email].join, "already has financial data"
  end

  test "accept_for refuses to move a user with data even if a pending invitation predates the data" do
    other_family = families(:empty)
    other_user = users(:empty)
    other_user.update_columns(family_id: other_family.id)

    # Invitation is created while the invitee still has no data, so it passes validation...
    invitation = @family.invitations.create!(email: other_user.email, role: "member", inviter: @inviter)
    assert invitation.pending?

    # ...but the invitee acquires real financial data in their own family before accepting.
    Account.create!(
      family: other_family,
      owner: other_user,
      name: "Other family checking",
      balance: 100,
      currency: "USD",
      accountable: Depository.new
    )

    result = invitation.accept_for(other_user)
    assert_not result, "accept_for must refuse to move a user with data even if an older pending invitation exists"
    other_user.reload
    assert_equal other_family.id, other_user.family_id
    invitation.reload
    assert_nil invitation.accepted_at
  end

  test "can invite a user who belongs to another family but owns no data there" do
    other_family = families(:empty)
    other_user = users(:empty)
    other_user.update_columns(family_id: other_family.id)

    invitation = @family.invitations.build(email: other_user.email, role: "member", inviter: @inviter)

    assert invitation.valid?
  end

  test "accept_for applies guest role defaults" do
    user = users(:family_member)
    user.update!(
      family_id: @family.id,
      role: "member",
      ui_layout: "dashboard",
      show_sidebar: true,
      show_ai_sidebar: true,
      ai_enabled: false
    )
    invitation = @family.invitations.create!(email: user.email, role: "guest", inviter: @inviter)

    result = invitation.accept_for(user)

    assert result
    user.reload
    assert_equal "guest", user.role
    assert user.ui_layout_intro?
    assert_not user.show_sidebar?
    assert_not user.show_ai_sidebar?
    # The preference alone does not grant AI access (E6): the family must
    # have explicitly consented, which this auto-defaulted guest has not.
    assert user.ai_enabled
    assert_not user.ai_enabled?
  end
end
