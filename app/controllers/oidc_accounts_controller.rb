class OidcAccountsController < ApplicationController
  skip_authentication only: [ :link, :create_link, :new_user, :create_user ]
  layout "auth"

  def link
    # Check if there's pending OIDC auth in session
    @pending_auth = session[:pending_oidc_auth]

    if @pending_auth.nil?
      redirect_to new_session_path, alert: "No pending OIDC authentication found"
      return
    end

    @email = @pending_auth["email"]
    @user_exists = RlsContext.with_auth_bypass { User.exists?(email: @email) } if @email.present?

    # Check for a pending invitation for this email (invitations is FORCE RLS'd)
    @pending_invitation = if @email.present?
      RlsContext.with_auth_bypass(reason: "oidc_link_invitation_lookup") do
        Invitation.pending.find_by(email: @email)
      end
    end

    signup_open = !self_hosted? || Setting.onboarding_state != "closed"
    @allow_account_creation = @pending_invitation.present? || (signup_open && !AuthConfig.jit_link_only? && AuthConfig.allowed_oidc_domain?(@email))
  end

  def create_link
    @pending_auth = session[:pending_oidc_auth]

    if @pending_auth.nil?
      redirect_to new_session_path, alert: "No pending OIDC authentication found"
      return
    end

    # Verify user's password to confirm identity
    user = User.auth_authenticate_by(email: params[:email], password: params[:password])

    if user&.active?
      if user.otp_required?
        # Do NOT create OidcIdentity before MFA verification — an attacker who only
        # knows the password must not be able to bind an OIDC identity to an MFA account.
        @email = params[:email]
        @user_exists = true
        flash.now[:alert] = "Accounts with two-factor authentication must sign in directly before linking SSO."
        render :link, status: :unauthorized
        return
      end

      oidc_identity = RlsContext.with_auth_bypass(reason: "oidc_account_link") do
        OidcIdentity.create_from_omniauth(
          build_auth_hash(@pending_auth),
          user
        )
      end

      # Log account linking
      SsoAuditLog.log_link!(
        user: user,
        provider: @pending_auth["provider"],
        request: request
      )

      # Clear pending auth from session
      session.delete(:pending_oidc_auth)

      @session = create_session_for(user)
      notice = if accept_pending_invitation_for(user)
        t("invitations.accept_choice.joined_household")
      else
        t("sessions.openid_connect.account_linked", provider: @pending_auth["provider"])
      end
      redirect_to root_path, notice: notice
    else
      @email = params[:email]
      @user_exists = RlsContext.with_auth_bypass { User.exists?(email: @email) } if @email.present?
      flash.now[:alert] = "Invalid email or password"
      render :link, status: :unprocessable_entity
    end
  end

  def new_user
    # Check if there's pending OIDC auth in session
    @pending_auth = session[:pending_oidc_auth]

    if @pending_auth.nil?
      redirect_to new_session_path, alert: "No pending OIDC authentication found"
      return
    end

    # Pre-fill user details from OIDC provider
    @user = User.new(
      email: @pending_auth["email"],
      first_name: @pending_auth["first_name"],
      last_name: @pending_auth["last_name"]
    )
  end

  def create_user
    @pending_auth = session[:pending_oidc_auth]

    if @pending_auth.nil?
      redirect_to new_session_path, alert: "No pending OIDC authentication found"
      return
    end

    email = @pending_auth["email"]

    # Check for a pending invitation for this email (invitations is FORCE RLS'd)
    invitation = RlsContext.with_auth_bypass(reason: "oidc_create_user_invitation_lookup") do
      Invitation.pending.find_by(email: email)
    end
    signup_open = !self_hosted? || Setting.onboarding_state != "closed"

    # Respect global onboarding_state + JIT configuration unless invited.
    unless invitation.present? || (signup_open && !AuthConfig.jit_link_only? && AuthConfig.allowed_oidc_domain?(email))
      redirect_to new_session_path, alert: "SSO account creation is disabled. Please contact an administrator."
      return
    end

    # Create SSO-only user without local password.
    # Security: JIT users should NOT have password_digest set to prevent
    # chained authentication attacks where SSO users gain local login access
    # via password reset.
    # Allow user to edit first_name and last_name from the form, but email comes from OIDC
    user_params = params.fetch(:user, {}).permit(:first_name, :last_name)
    @user = User.new(
      email: email,
      first_name: user_params[:first_name].presence || @pending_auth["first_name"],
      last_name: user_params[:last_name].presence || @pending_auth["last_name"],
      skip_password_validation: true
    )

    if invitation.present?
      # Accept the pending invitation: join the existing family
      @user.family_id = invitation.family_id
      @user.role = invitation.role
    else
      # Create new family for this user
      @user.family = Family.new

      # Use provider-configured default role, or fall back to admin for family creators
      # First user of an instance always becomes super_admin regardless of provider config
      provider_config = Rails.configuration.x.auth.sso_providers&.find { |p| p[:name] == @pending_auth["provider"] }
      provider_default_role = provider_config&.dig(:settings, :default_role)
      @user.role = User.role_for_new_family_creator(fallback_role: provider_default_role || :admin)
    end

    RlsContext.with_auth_bypass(reason: "jit_signup") do
      if @user.save
        # Create the OIDC (or other SSO) identity
        identity = OidcIdentity.create_from_omniauth(
          build_auth_hash(@pending_auth),
          @user
        )

        # Only log JIT account creation if identity was successfully created
        if identity.persisted?
          SsoAuditLog.log_jit_account_created!(
            user: @user,
            provider: @pending_auth["provider"],
            request: request
          )
        end

        # Mark invitation as accepted if one was used
        invitation&.update!(accepted_at: Time.current)

        # Clear pending auth from session
        session.delete(:pending_oidc_auth)

        @session = create_session_for(@user)
        notice = if invitation.present?
          t("invitations.accept_choice.joined_household")
        elsif accept_pending_invitation_for(@user)
          t("invitations.accept_choice.joined_household")
        else
          "Welcome! Your account has been created."
        end
        redirect_to root_path, notice: notice
      else
        render :new_user, status: :unprocessable_entity
      end
    end
  end

  private

    # Convert pending auth hash to OmniAuth-like structure
    def build_auth_hash(pending_auth)
      OpenStruct.new(
        provider: pending_auth["provider"],
        uid: pending_auth["uid"],
        info: OpenStruct.new(pending_auth.slice("email", "name", "first_name", "last_name"))
      )
    end
end
