class InvitationsController < ApplicationController
  skip_authentication only: :accept
  def new
    @invitation = Invitation.new
  end

  def create
    unless Current.user.admin?
      flash[:alert] = t(".failure")
      redirect_to settings_profile_path
      return
    end

    @invitation = Current.family.invitations.build(invitation_params)
    @invitation.inviter = Current.user

    if @invitation.save
      # Whether the invited email belongs to a brand-new visitor or an
      # existing account holder, the invitation stays pending until the
      # invitee explicitly accepts it themselves (see #accept /
      # #confirm_accept). We never move an existing user's account for them.
      InvitationMailer.invite_email(@invitation).deliver_later unless self_hosted?
      flash[:notice] = t(".success")
    else
      flash[:alert] = t(".failure")
    end

    redirect_to settings_profile_path
  rescue ActiveRecord::RecordNotUnique
    flash[:alert] = t(".failure")
    redirect_to settings_profile_path
  end

  def accept
    # Unauthenticated by design (skip_authentication above) -- the whole
    # point of an invitation is reaching someone with no session and no
    # family yet, so current_family_id is NULL here. invitations is under
    # FORCE ROW LEVEL SECURITY; without this, RLS hides every invitation
    # from its own accept link. family/inviter are eager-loaded here too:
    # the view reads both, and letting that lazy-load after this block exits
    # would run it back outside the bypass.
    @invitation = RlsContext.with_auth_bypass(reason: "invitations_accept") do
      Invitation.includes(:family, :inviter).find_by!(token: params[:id])
    end

    if @invitation.pending?
      # If the person clicking the link is already signed in to the account
      # the invitation was sent to, skip the sign-in/create-account choice
      # and show an explicit "this will move you" confirmation instead.
      @invitee_signed_in = Current.user.present? &&
        Current.user.email.to_s.strip.downcase == @invitation.email.to_s.strip.downcase

      render :accept_choice, layout: "auth"
    else
      raise ActiveRecord::RecordNotFound
    end
  end

  # Explicit, authenticated acceptance of an invitation by the invitee
  # themselves, from their own session. This is the only path (besides the
  # new-registration flow) that ever moves an existing user into another
  # family -- an admin sending an invitation never does this on its own.
  def confirm_accept
    # Current.user is authenticated here, but under their OWN (or no)
    # family -- this invitation belongs to a DIFFERENT family by design
    # (that's the family they're being invited to join), so both finding it
    # AND accept_for's writes (moving the user into that family) are a
    # deliberate cross-family operation that current_family_id's normal
    # scoping can never satisfy, same reasoning as #accept above.
    accepted = RlsContext.with_auth_bypass(reason: "invitations_confirm_accept") do
      @invitation = Invitation.find_by!(token: params[:id])
      @invitation.accept_for(Current.user)
    end

    if accepted
      flash[:notice] = t("invitations.accept_choice.joined_household")
    else
      flash[:alert] = t("invitations.confirm_accept.failure")
    end

    redirect_to root_path
  end

  def destroy
    unless Current.user.admin?
      flash[:alert] = t("invitations.destroy.not_authorized")
      redirect_to settings_profile_path
      return
    end

    @invitation = Current.family.invitations.find(params[:id])

    if @invitation.destroy
      flash[:notice] = t("invitations.destroy.success")
    else
      flash[:alert] = t("invitations.destroy.failure")
    end

    redirect_to settings_profile_path
  end

  private

    def invitation_params
      params.require(:invitation).permit(:email, :role)
    end
end
