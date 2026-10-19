module StoreLocation
  extend ActiveSupport::Concern

  included do
    helper_method :previous_path
    before_action :store_return_to
    after_action :clear_previous_path

    rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
  end

  def previous_path
    safe_return_to_path(session[:return_to]) || fallback_path
  end

private
  # `return_to` comes straight off the query string, so it is
  # attacker-controlled, and it reaches `redirect_to` in
  # SessionsController#create and MfaController#verify_code. Only a
  # root-relative path on this host is ever legitimate here.
  #
  # Two framework defaults happen to cover the two attacks today --
  # `raise_on_open_redirects` (on via `load_defaults 7.2`) turns an absolute
  # external URL into an exception rather than a redirect, and the nonce-only
  # CSP with no `unsafe_inline` blocks a `javascript:` value -- but each is one
  # config flip away (`allow_other_host: true`, `CSP_REPORT_ONLY=true`). So
  # validate here as well, rather than relying on them.
  #
  # Three provider controllers (lunchflow, mercury, sophtron) each carried
  # their own copy of this. Only sophtron's checked `uri.host` and the `//`
  # prefix; the other two accepted "//evil.com", which URI.parse reports with
  # no scheme and host "evil.com" and which starts with "/" -- so it passed,
  # and a browser resolves it to an external host. They now all call this.
  #
  # Same-host ABSOLUTE urls have to be allowed, not just relative paths:
  # Doorkeeper's resource_owner_authenticator stores the whole
  # /oauth/authorize url (request.url), which is how native-app login resumes
  # after the web login screen. test/integration/oauth_mobile_login_resume_test.rb
  # asserts that shape explicitly.
  def safe_return_to_path(value = params[:return_to])
    return nil if value.blank?

    candidate = value.to_s
    uri = URI.parse(candidate)

    if uri.host.present?
      # Absolute (or protocol-relative, which URI reports as host with no
      # scheme). Only this host, only over http(s).
      return nil unless %w[http https].include?(uri.scheme)
      return nil unless uri.host == request.host
    else
      # Relative. Reject other schemes (javascript:, data:) and anything that
      # is not root-relative.
      return nil if uri.scheme.present?
      return nil unless candidate.start_with?("/")
    end

    candidate
  rescue URI::InvalidURIError
    nil
  end

  # Reads and clears `return_to` for a redirect. Validated on the way out too:
  # a session created before this validation existed can still carry an unsafe
  # value, and sessions live up to the 14-day absolute timeout.
  def consume_return_to
    safe_return_to_path(session.delete(:return_to))
  end

  def handle_not_found
    if request.fullpath == session[:return_to]
      session.delete(:return_to)
      redirect_to fallback_path
    else
      head :not_found
    end
  end

  def store_return_to
    safe = safe_return_to_path
    session[:return_to] = safe if safe.present?
  end

  def clear_previous_path
    if request.fullpath == session[:return_to]
      session.delete(:return_to)
    end
  end

  def fallback_path
    root_path
  end
end
