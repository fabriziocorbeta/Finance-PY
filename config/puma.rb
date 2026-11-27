# This configuration file will be evaluated by Puma. The top-level methods that
# are invoked here are part of Puma's configuration DSL. For more information
# about methods provided by the DSL, see https://puma.io/puma/Puma/DSL.html.

rails_env = ENV.fetch("RAILS_ENV", "development")

# Puma starts a configurable number of processes (workers) and each process
# serves each request in a thread from an internal thread pool.
#
# The ideal number of threads per worker depends both on how much time the
# application spends waiting for IO operations and on how much you wish to
# to prioritize throughput over latency.
#
# As a rule of thumb, increasing the number of threads will increase how much
# traffic a given process can handle (throughput), but due to CRuby's
# Global VM Lock (GVL) it has diminishing returns and will degrade the
# response time (latency) of the application.
#
# The default is set to 3 threads as it's deemed a decent compromise between
# throughput and latency for the average Rails application.
#
# Any libraries that use a connection pool or another resource pool should
# be configured to provide at least as many connections as the number of
# threads. This includes Active Record's `pool` parameter in `database.yml`.
threads_count = ENV.fetch("RAILS_MAX_THREADS") { 3 }
threads threads_count, threads_count

if rails_env == "production"
  # If you are running more than 1 thread per process, the workers count
  # should be equal to the number of processors (CPU cores) in production.
  #
  # It defaults to 1 because it's impossible to reliably detect how many
  # CPU cores are available. Make sure to set the `WEB_CONCURRENCY` environment
  # variable to match the number of processors.
  workers_count = Integer(ENV.fetch("WEB_CONCURRENCY") { 1 })
  workers workers_count if workers_count > 1

  preload_app!
end

# Specifies the `port` that Puma will listen on to receive requests; default is 3000.
# The bind host is controlled via the Rails-native `BINDING` env var (set to
# `0.0.0.0` in containers, or `::` for IPv6 dual-stack). See docs/hosting/docker.md.
port ENV.fetch("PORT") { 3000 }

# Specifies the `environment` that Puma will run in.
environment rails_env

# Allow puma to be restarted by `bin/rails restart` command.
plugin :tmp_restart

pidfile ENV["PIDFILE"] if ENV["PIDFILE"]

if rails_env == "development"
  # Specifies a very generous `worker_timeout` so that the worker
  # isn't killed by Puma when suspended by a debugger.
  worker_timeout 3600
end

if rails_env == "production"
  # ActionView compiles each template into a Ruby method the first time it's
  # rendered in a process, not at boot (eager_load only eager-loads classes,
  # not views). On this deploy that means whoever makes the first real
  # request to a given page after a restart pays that one-time compile cost
  # on top of the page's normal query time — measured at +15s for the
  # dashboard (24.7s cold vs 9.0s warm, identical 40 queries either way).
  # Hitting the hot pages here, once, right after Puma starts accepting
  # connections, pays that cost during deploy instead of on a real visitor.
  #
  # Runs as a real loopback HTTP request (not an in-process Rack dispatch)
  # because Rails.application is still mid-boot during earlier hooks like
  # config.after_initialize — dispatching into it from inside its own boot
  # sequence 404s (routes aren't finalized yet). By `on_booted`, the server
  # is genuinely listening, so a normal request behaves exactly like a real
  # visitor's.
  on_booted do
    Thread.new do
      warmup_session = nil
      begin
        require "net/http"

        Rails.application.executor.wrap do
          warmup_session = RlsContext.with_auth_bypass(reason: "puma_boot_warmup") do
            uid = Account.group(:owner_id).count.max_by { |_, c| c }&.first
            user = (uid && User.find_by(id: uid)) || User.order(:created_at).first
            user&.sessions&.create!
          end
        end

        unless warmup_session
          Rails.logger.info "[warmup] skipped: no user in DB to render as"
          next
        end

        env = Rails.application.env_config.merge(
          Rack::MockRequest.env_for("https://finance.cd-co.com.py/")
        )
        setup_request = ActionDispatch::Request.new(env)
        jar = ActionDispatch::Cookies::CookieJar.build(setup_request, {})
        jar.signed[:session_token] = warmup_session.id
        cookie_header = jar.to_header

        port = ENV.fetch("PORT") { 3000 }
        paths = [
          "/",
          "/accounts/sidebar",
          "/transactions?page=1&per_page=50",
          "/investments",
          "/budgets/#{Budget.date_to_param(Date.current)}",
          "/reports",
          "/accounts",
          "/goals",
          "/receivables",
          "/sales",
          "/purchase_orders",
          "/products",
          "/fleet_vehicles"
        ]

        total_t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        Net::HTTP.start("127.0.0.1", port) do |http|
          paths.each do |path|
            request = Net::HTTP::Get.new(path)
            request["Cookie"] = cookie_header
            request["Host"] = "finance.cd-co.com.py"
            request["X-Forwarded-Proto"] = "https"

            page_t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
            response = http.request(request)
            if response.code == "302" && response["location"].present?
              loc_uri = URI.parse(response["location"])
              follow_req = Net::HTTP::Get.new(loc_uri.request_uri)
              follow_req["Cookie"] = cookie_header
              follow_req["Host"] = "finance.cd-co.com.py"
              follow_req["X-Forwarded-Proto"] = "https"
              response = http.request(follow_req)
            end
            page_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - page_t0) * 1000).round
            Rails.logger.info "[warmup] #{path} -> #{response.code} in #{page_ms}ms"
          end
        end
        total_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - total_t0) * 1000).round
        Rails.logger.info "[warmup] done in #{total_ms}ms"
      rescue => e
        Rails.logger.error "[warmup] failed: #{e.class}: #{e.message}"
      ensure
        if warmup_session
          Rails.application.executor.wrap do
            RlsContext.with_auth_bypass(reason: "puma_boot_warmup_cleanup") do
              warmup_session.destroy rescue nil
            end
          end
        end
      end
    end
  end
end
