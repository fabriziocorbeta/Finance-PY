# frozen_string_literal: true

class Rack::Attack
  # Enable Rack::Attack only in production and staging (disable in test/development to avoid rate-limit flakiness)
  enabled = Rails.env.production? || Rails.env.staging?
  self.enabled = enabled

  # Throttle requests to the OAuth token endpoint
  throttle("oauth/token", limit: 10, period: 1.minute) do |request|
    request.ip if request.path == "/oauth/token"
  end

  # Throttle browser password sign-in (POST /sessions) to prevent brute-force
  throttle("login/ip", limit: 10, period: 1.minute) do |request|
    request.ip if request.post? && request.path == "/sessions"
  end

  # Throttle the mobile/API login endpoint (POST /api/v1/auth/login)
  throttle("api_login/ip", limit: 10, period: 1.minute) do |request|
    request.ip if request.post? && request.path == "/api/v1/auth/login"
  end

  # Throttle unauthenticated WebAuthn MFA ceremonies similarly to sign-in
  # endpoints; registration remains behind normal application authentication.
  throttle("mfa/webauthn", limit: 10, period: 1.minute) do |request|
    if request.post? && request.path.in?(%w[/mfa/webauthn_options /mfa/verify_webauthn])
      request.ip
    end
  end

  # Email named by the request, from a form field or a (small) JSON body, normalized.
  def self.email_from(request)
    email = request.params["email"]
    if email.blank? && request.media_type == "application/json"
      raw = request.body.read(10_000).to_s
      request.body.rewind
      email = (JSON.parse(raw)["email"] rescue nil)
    end
    email.to_s.strip.downcase.presence
  end

  # TOTP codes (web MFA step, 6 digits): same treatment as the sign-in endpoints.
  # (The webauthn ceremonies above are separate paths.) Per-account lockout lives
  # in User#verify_otp_with_lockout?.
  throttle("mfa/verify_code", limit: 10, period: 1.minute) do |request|
    request.ip if request.post? && request.path == "/mfa/verify"
  end

  # Per-account throttle on password sign-in: credential stuffing rotates IPs, but
  # every attempt against one account names the same email.
  throttle("login/email", limit: 10, period: 15.minutes) do |request|
    if request.post? && request.path.in?(%w[/sessions /api/v1/auth/login])
      email = email_from(request)
      "login_email:#{Digest::SHA256.hexdigest(email)}" if email
    end
  end

  # Password reset: request (email flood / enumeration probing) and completion (token guessing).
  throttle("password_reset/ip", limit: 5, period: 1.minute) do |request|
    request.ip if request.path == "/password_reset" && !request.get?
  end

  throttle("password_reset/email", limit: 3, period: 15.minutes) do |request|
    if request.post? && request.path == "/password_reset"
      email = email_from(request)
      "reset_email:#{Digest::SHA256.hexdigest(email)}" if email
    end
  end

  # Account creation (web and API): slow down mass signup and email enumeration.
  throttle("signup/ip", limit: 10, period: 1.hour) do |request|
    request.ip if request.post? && request.path.in?(%w[/registration /api/v1/auth/signup])
  end

  # Token refresh and SSO linking are unauthenticated entry points.
  throttle("api_auth/ip", limit: 30, period: 1.minute) do |request|
    request.ip if request.post? && request.path.in?(%w[/api/v1/auth/refresh /api/v1/auth/sso_link])
  end

  # Throttle admin endpoints to prevent brute-force attacks
  # More restrictive than general API limits since admin access is sensitive
  throttle("admin/ip", limit: 10, period: 1.minute) do |request|
    request.ip if request.path.start_with?("/admin/")
  end

  # Cheap, DB-free identifier for the actor behind a request, for throttles below.
  # We can't resolve user/family here without a query (the session cookie only
  # holds a Session#id; family lives on session.user.family), so we group by the
  # opaque token instead: the raw signed session cookie for the browser, or the
  # bearer token for the API/MCP. Both are unique per authenticated actor already,
  # so hashing them (without verifying/decrypting) is enough to rate-limit per
  # actor rather than per IP, at zero extra query cost. Falls back to IP when
  # neither is present (logged-out requests, which authenticate_user! rejects
  # anyway, but the throttle must still return *some* key or Rack::Attack skips it).
  def self.actor_key(request)
    session_cookie = request.cookies["session_token"]
    return "actor_session:#{Digest::SHA256.hexdigest(session_cookie)}" if session_cookie.present?

    auth_header = request.get_header("HTTP_AUTHORIZATION")
    if auth_header&.start_with?("Bearer ")
      return "actor_token:#{Digest::SHA256.hexdigest(auth_header.delete_prefix("Bearer ").strip)}"
    end

    "actor_ip:#{request.ip}"
  end

  # --- Cost-sensitive endpoints (E5): chat/LLM calls, imports, exports, MCP ---
  # These all trigger paid LLM calls, PDF parsing, or full-family data dumps, so
  # they're throttled tighter than the general API limits above and keyed by
  # actor (see actor_key) rather than raw IP so one user can't just rotate IPs.

  MESSAGE_CREATE_PATHS = %r{\A/(?:api/v1/)?chats/\d+/messages\z}

  # New chat creation (starts a chat + first LLM call)
  throttle("chats/create", limit: 20, period: 1.hour) do |request|
    if request.post? && request.path.in?(%w[/chats /api/v1/chats])
      actor_key(request)
    end
  end

  # Follow-up messages in an existing chat (one LLM call each)
  throttle("messages/create", limit: 60, period: 1.hour) do |request|
    if request.post? && request.path.match?(MESSAGE_CREATE_PATHS)
      actor_key(request)
    end
  end

  # PDF/CSV imports (parsing +, for PDFs, an LLM extraction call per chunk)
  throttle("imports/create", limit: 20, period: 1.hour) do |request|
    if request.post? && request.path.in?(%w[/imports /api/v1/imports])
      actor_key(request)
    end
  end

  # Bank statement imports (PDF parsing, no LLM call, but still I/O heavy)
  throttle("statement_imports/create", limit: 20, period: 1.hour) do |request|
    request.post? && request.path == "/statement_imports" ? actor_key(request) : nil
  end

  # Full family data exports (expensive query + file generation)
  throttle("family_exports/create", limit: 5, period: 1.hour) do |request|
    if request.post? && request.path.in?(%w[/family_exports /api/v1/family_exports])
      actor_key(request)
    end
  end

  # MCP JSON-RPC endpoint: external AI assistants, one request per tool call.
  # Keyed by actor only (session cookies are never sent to /mcp -- it's
  # token-only, see McpController#authenticate_mcp_token!) so this always
  # resolves to the bearer token or, failing that, IP.
  throttle("mcp/requests", limit: 120, period: 1.minute) do |request|
    actor_key(request) if request.path == "/mcp"
  end

  # Determine limits based on self-hosted mode
  self_hosted = Rails.application.config.app_mode.self_hosted?

  # Throttle API requests per access token
  throttle("api/requests", limit: self_hosted ? 10_000 : 100, period: 1.hour) do |request|
    if request.path.start_with?("/api/")
      # Extract access token from Authorization header
      auth_header = request.get_header("HTTP_AUTHORIZATION")
      if auth_header&.start_with?("Bearer ")
        token = auth_header.split(" ").last
        "api_token:#{Digest::SHA256.hexdigest(token)}"
      else
        # Fall back to IP-based limiting for unauthenticated requests
        "api_ip:#{request.ip}"
      end
    end
  end

  # More permissive throttling for API requests by IP (for development/testing)
  throttle("api/ip", limit: self_hosted ? 20_000 : 200, period: 1.hour) do |request|
    request.ip if request.path.start_with?("/api/")
  end

  # Block requests that appear to be malicious
  blocklist("block malicious requests") do |request|
    # Block requests with suspicious user agents
    suspicious_user_agents = [
      /sqlmap/i,
      /nmap/i,
      /nikto/i,
      /masscan/i
    ]

    user_agent = request.user_agent
    suspicious_user_agents.any? { |pattern| user_agent =~ pattern } if user_agent
  end

  # Configure response for throttled requests
  self.throttled_responder = lambda do |request|
    [
      429, # status
      {
        "Content-Type" => "application/json",
        "Retry-After" => "60"
      },
      [ { error: "Rate limit exceeded. Try again later." }.to_json ]
    ]
  end

  # Configure response for blocked requests
  self.blocklisted_responder = lambda do |request|
    [
      403, # status
      { "Content-Type" => "application/json" },
      [ { error: "Request blocked." }.to_json ]
    ]
  end
end
