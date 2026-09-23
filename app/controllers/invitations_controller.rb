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
    @invitation = Invitation.find_by!(token: params[:id])

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
    @invitation = Invitation.find_by!(token: params[:id])

    if @invitation.accept_for(Current.user)
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
