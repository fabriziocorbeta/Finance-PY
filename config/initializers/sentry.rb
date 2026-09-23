require "active_support/parameter_filter"

# Field names that must never leave this app in plaintext -- kept in sync
# with config/initializers/filter_parameter_logging.rb so Sentry events get
# the same treatment as the Rails log. Defined unconditionally (not inside
# the SENTRY_DSN guard below) so it's a plain, testable module regardless
# of whether Sentry is actually configured in this environment.
module SentryPiiScrubber
  SENSITIVE_FIELDS = %w[
    passw email secret token _key crypt salt certificate otp ssn openai_access_token
    client_id consumer_key snaptrade_user_id snaptrade_user_secret
    amount name notes description balance client_name address phone ruc merchant
  ].freeze

  PARAMETER_FILTER = ActiveSupport::ParameterFilter.new(SENSITIVE_FIELDS)

  # Recursively scrubs any hash/array/JSON-string structure that may end up
  # on a Sentry event (request body, breadcrumb data, extras) so financial
  # data never reaches Sentry even if send_default_pii is ever flipped on
  # by mistake, or a breadcrumb payload carries params we don't control
  # directly.
  def self.scrub(value)
    case value
    when Hash
      PARAMETER_FILTER.filter(value)
    when String
      begin
        parsed = JSON.parse(value)
        scrub(parsed).to_json
      rescue JSON::ParserError
        value
      end
    else
      value
    end
  end
end

if ENV["SENTRY_DSN"].present?
  Sentry.init do |config|
    config.dsn = ENV["SENTRY_DSN"]
    config.environment = ENV["RAILS_ENV"]
    config.breadcrumbs_logger = [ :active_support_logger, :http_logger ]
    config.enabled_environments = %w[production]

    # Never let Sentry collect request bodies, cookies, IPs or the
    # X-Forwarded-For/Authorization headers by default -- financial data
    # (amounts, notes, client names) travels in request bodies.
    config.send_default_pii = false

    # Disable log forwarding to Sentry: Rails.logger lines can contain
    # inspected financial payloads (see Provider::Openai#record_llm_usage),
    # and Sentry's log ingestion is a second, separate destination the
    # filter_parameter_logging.rb filters don't reach.
    config.enable_logs = false
    config.enabled_patches = []

    # Defense in depth: even with send_default_pii off, scrub any
    # request/breadcrumb data that does make it onto an event before it
    # leaves the process, using the same sensitive-field list as the Rails
    # log filter.
    config.before_send = lambda do |event, _hint|
      if event.respond_to?(:request) && event.request&.data
        event.request.data = SentryPiiScrubber.scrub(event.request.data)
      end
      event
    end

    config.before_breadcrumb = lambda do |breadcrumb, _hint|
      breadcrumb.data = SentryPiiScrubber.scrub(breadcrumb.data) if breadcrumb.data
      breadcrumb
    end

    # Set traces_sample_rate to 1.0 to capture 100%
    # of transactions for performance monitoring.
    # We recommend adjusting this value in production.
    config.traces_sample_rate = 0.25

    # Set profiles_sample_rate to profile 100%
    # of sampled transactions.
    # We recommend adjusting this value in production.
    config.profiles_sample_rate = 0.25

    config.release = Rails.root.join(".sure-version").read.strip rescue nil
    config.profiler_class = Sentry::Vernier::Profiler
  end
end
