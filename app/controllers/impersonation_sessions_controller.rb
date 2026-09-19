class ImpersonationSessionsController < ApplicationController
  before_action :require_super_admin!, only: [ :create, :join, :leave ]
  before_action :require_recent_credentials!, only: :create
  before_action :set_impersonation_session, only: [ :approve, :reject, :complete ]

  def create
    request = Current.true_user.request_impersonation_for(session_params[:impersonated_id])
    ImpersonationMailer.with(impersonation_session: request).requested.deliver_later
    redirect_to root_path, notice: t(".success")
  end

  def join
    @impersonation_session = Current.true_user.impersonator_support_sessions.active.find_by(id: params[:impersonation_session_id])
    return redirect_to(root_path, alert: "That session is not active (expired or ended).") unless @impersonation_session
    Current.session.update!(active_impersonator_session: @impersonation_session)
    redirect_to root_path, notice: t(".success")
  end

  def leave
    Current.session.update!(active_impersonator_session: nil)
    redirect_to root_path, notice: t(".success")
  end

  def approve
    raise_unauthorized! unless @impersonation_session.impersonated == Current.true_user

    if @impersonation_session.approve!
      redirect_to root_path, notice: t(".success")
    else
      redirect_to root_path, alert: "This access request expired. Ask support to send a new one."
    end
  end

  def reject
    raise_unauthorized! unless @impersonation_session.impersonated == Current.true_user

    @impersonation_session.reject!
    redirect_to root_path, notice: t(".success")
  end

  def complete
    @impersonation_session.complete!
    redirect_to root_path, notice: t(".success")
  end

  private
    # Starting an impersonation needs fresh proof it is really the super admin:
    # password, plus the MFA code when MFA is on. A stolen browser session alone
    # is not enough to open a customer's account.
    def require_recent_credentials!
      user = Current.true_user
      verified = user.authenticate(params[:password].to_s).present?
      verified &&= user.verify_otp?(params[:otp_code].to_s) if user.otp_required?
      redirect_to root_path, alert: "Re-authentication failed: password#{user.otp_required? ? " or MFA code" : ""} is incorrect." unless verified
    end

    def session_params
      params.require(:impersonation_session).permit(:impersonated_id)
    end

    def set_impersonation_session
      @impersonation_session =
        Current.true_user.impersonated_support_sessions.find_by(id: params[:id]) ||
        Current.true_user.impersonator_support_sessions.find_by(id: params[:id])
    end

    def require_super_admin!
      raise_unauthorized! unless Current.true_user&.super_admin?
    end

    def raise_unauthorized!
      raise ActionController::RoutingError.new("Not Found")
    end
end
