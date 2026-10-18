class EmailConfirmationsController < ApplicationController
  skip_before_action :set_request_details, only: :new
  skip_authentication only: :new

  def new
    # Returns nil if the token is invalid OR expired
    @user = User.find_by_token_for(:email_confirmation, params[:token])

    # `users` is FORCE ROW LEVEL SECURITY with family isolation and this action
    # is unauthenticated, so `app.current_family_id` is never set. Without a
    # bypass the UPDATE matches zero rows and still returns true (`users` has no
    # `lock_version`), so the email silently never changes while the user is
    # told it was confirmed. Same trap as PasswordResetsController#update.
    confirmed = RlsContext.with_auth_bypass(reason: "email_confirmation") do
      @user&.unconfirmed_email.present? && @user.update(
        email: @user.unconfirmed_email,
        unconfirmed_email: nil
      )
    end

    if confirmed
      redirect_to new_session_path, notice: t(".success_login")
    else
      redirect_to root_path, alert: t(".invalid_token")
    end
  end
end
