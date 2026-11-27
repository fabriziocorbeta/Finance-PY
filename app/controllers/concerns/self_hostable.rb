module SelfHostable
  extend ActiveSupport::Concern

  REDIS_HEALTH_TTL_SECONDS = 30.0
  @redis_health_mutex = Mutex.new
  @redis_healthy_until = 0.0
  @redis_health_client = nil

  class << self
    def redis_healthy?(force: false)
      return ping_fresh_client if Rails.env.test?

      now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      return true if !force && now < @redis_healthy_until

      @redis_health_mutex.synchronize do
        now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        return true if !force && now < @redis_healthy_until

        @redis_health_client ||= Redis.new
        @redis_health_client.ping
        @redis_healthy_until = now + REDIS_HEALTH_TTL_SECONDS
        true
      rescue Redis::BaseError
        @redis_health_client = nil
        @redis_healthy_until = 0.0
        false
      end
    end

    private
      def ping_fresh_client
        Redis.new.ping
        true
      rescue Redis::CannotConnectError, Redis::BaseConnectionError
        false
      end
  end

  included do
    helper_method :self_hosted?, :self_hosted_first_login?

    prepend_before_action :verify_self_host_config
  end

  private
    def self_hosted?
      Rails.configuration.app_mode.self_hosted?
    end

    def self_hosted_first_login?
      self_hosted? && (RlsContext.with_auth_bypass(reason: "self_hosted_check") { User.count.zero? })
    end

    def verify_self_host_config
      return unless self_hosted?

      # Special handling for Redis configuration error page
      if controller_name == "pages" && action_name == "redis_configuration_error"
        # If Redis is now working, redirect to home
        if redis_connected?(force: true)
          redirect_to root_path, notice: "Redis is now configured properly! You can now setup your Sure application."
        end

        return
      end

      unless redis_connected?
        redirect_to redis_configuration_error_path
      end
    end

    def redis_connected?(force: false)
      SelfHostable.redis_healthy?(force: force)
    end
end
