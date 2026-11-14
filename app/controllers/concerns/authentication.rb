module Authentication
  extend ActiveSupport::Concern

  INACTIVITY_TIMEOUT = Session::INACTIVITY_TIMEOUT
  ABSOLUTE_TIMEOUT = Session::ABSOLUTE_TIMEOUT

  def self.session_cookie_options(env: Rails.env)
    {
      httponly: true,
      same_site: :lax,
      secure: env.production?
    }
  end

  included do
    before_action :set_request_details
    before_action :authenticate_user!
    before_action :set_sentry_user
  end

  class_methods do
    def skip_authentication(**options)
      skip_before_action :authenticate_user!, **options
      skip_before_action :set_sentry_user, **options
    end
  end

  private
    def authenticate_user!
      if session_record = find_session_by_cookie
        if session_expired?(session_record)
          RlsContext.with_auth_bypass(reason: "destroy_expired_session") do
            session_record.destroy
          end
          cookies.delete(:session_token, **Authentication.session_cookie_options)
          redirect_to new_session_url, alert: "Tu sesión ha expirado por inactividad."
          return
        end

        Current.session = session_record
        # Current.family (delegate to user.family, an AR association) issues a
        # SELECT against `families` -- with families under FORCE ROW LEVEL
        # SECURITY, that query runs before app.current_family_id is set and
        # returns zero rows (id = NULL is never true), leaving Current.family
        # nil and the RLS context never established for the whole request.
        # user.family_id is the raw FK column: no query, no chicken-and-egg.
        RlsContext.set_family(Current.user&.family_id)
        session_record.touch
      else
        if self_hosted_first_login?
          redirect_to new_registration_url
        else
          redirect_to new_session_url
        end
      end
    end

    def session_expired?(session_record)
      session_record.expired?
    end

    def find_session_by_cookie
      cookie_value = cookies.signed[:session_token]

      if cookie_value.present?
        RlsContext.with_auth_bypass(reason: "find_session_by_cookie") do
          Session.includes(:user).find_by(id: cookie_value)
        end
      else
        nil
      end
    end

    def create_session_for(user)
      session = RlsContext.with_auth_bypass(reason: "create_session") do
        user.sessions.create!
      end
      cookies.signed.permanent[:session_token] = Authentication.session_cookie_options.merge(value: session.id)
      session
    end

    def self_hosted_first_login?
      Rails.application.config.app_mode.self_hosted? && (RlsContext.with_auth_bypass(reason: "self_hosted_check") { User.count.zero? })
    end

    def set_request_details
      Current.user_agent = request.user_agent
      Current.ip_address = request.ip
    end

    def set_sentry_user
      return unless defined?(Sentry) && ENV["SENTRY_DSN"].present?

      if Current.user
        Sentry.set_user(
          id: Current.user.id
        )
      end
    end
end
