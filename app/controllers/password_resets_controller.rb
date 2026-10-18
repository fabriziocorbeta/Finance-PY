class PasswordResetsController < ApplicationController
  skip_authentication

  layout "auth"

  before_action :ensure_password_resets_enabled
  before_action :set_user_by_token, only: %i[edit update]
  around_action :with_rls_auth_bypass, only: %i[create update]

  def new
  end

  def create
    if (user = User.auth_find_by_email(params[:email]))
      # Security: Block password reset for SSO-only users.
      # These users have no local password and must authenticate via SSO.
      unless user.sso_only?
        PasswordMailer.with(
          user: user,
          token: user.generate_token_for(:password_reset)
        ).password_reset.deliver_later
      end
    end

    # Always redirect to pending step to prevent email enumeration
    redirect_to new_password_reset_path(step: "pending")
  end

  def edit
    @user = User.new
  end

  def update
    # Security: Block password setting for SSO-only users.
    # Defense-in-depth: even if they somehow get a reset token, block the update.
    if @user.sso_only?
      redirect_to new_session_path, alert: t("password_resets.sso_only_user")
      return
    end

    if @user.update(password_params)
      @user.revoke_all_oauth_tokens!
      @user.revoke_all_sessions!
      redirect_to new_session_path, notice: t(".success")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

    # `users` and `oidc_identities` are both FORCE ROW LEVEL SECURITY with
    # family isolation, and this controller is `skip_authentication`, so
    # `app.current_family_id` is never set here. Without a bypass:
    #
    #   - `sso_only?` (`password_digest.nil? && oidc_identities.exists?`) reads
    #     zero `oidc_identities` rows and returns false, so the SSO-only guard
    #     never fires;
    #   - `@user.update(password_params)` matches zero rows and *still returns
    #     true* -- `users` has no `lock_version`, so ActiveRecord never notices
    #     the empty UPDATE. The password silently never changes while the user
    #     is redirected with the success notice.
    #
    # The guard and the write must share one bypass. Bypassing only the write
    # would make the first bullet exploitable: an SSO-only user could set a
    # local password with a reset token.
    #
    # `User.find_by_token_for` wraps itself (app/models/user.rb), which is why
    # `set_user_by_token` already works outside this block.
    def with_rls_auth_bypass(&block)
      RlsContext.with_auth_bypass(reason: "password_reset_#{action_name}", &block)
    end

    def ensure_password_resets_enabled
      return if AuthConfig.password_features_enabled?

      redirect_to new_session_path, alert: t("password_resets.disabled")
    end

    def set_user_by_token
      @user = User.find_by_token_for(:password_reset, params[:token])
      redirect_to new_password_reset_path, alert: t("password_resets.update.invalid_token") unless @user.present?
    end

    def password_params
      params.require(:user).permit(:password, :password_confirmation)
    end
end
