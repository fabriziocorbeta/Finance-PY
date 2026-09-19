# Tells a customer that support asked to access their account. Deliberately
# plain and bilingual (ES/EN): it is a security notice, and it never contains a
# link that grants access -- approval happens inside the signed-in app.
class ImpersonationMailer < ApplicationMailer
  def requested
    session = params[:impersonation_session]
    @user = session.impersonated
    @minutes = ImpersonationSession::REQUEST_TTL.in_minutes.to_i
    @hours = ImpersonationSession::SESSION_TTL.in_hours.to_i

    mail to: @user.email, subject: "Soporte pidió acceso a tu cuenta / Support requested access to your account"
  end
end
