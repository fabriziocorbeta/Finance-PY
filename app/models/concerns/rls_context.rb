# frozen_string_literal: true

module RlsContext
  class << self
    def set_family(family_or_id)
      family_id = case family_or_id
      when Family then family_or_id.id
      when String, Integer then family_or_id
      else family_or_id&.id if family_or_id.respond_to?(:id)
      end

      if family_id.present?
        ActiveRecord::Base.connection.execute(
          ActiveRecord::Base.sanitize_sql([ "SET app.current_family_id = ?", family_id ])
        )
      else
        reset
      end
    end

    # Resets app.current_family_id on the connection currently leased to this
    # thread. Never raises: callers (around_action/around_perform `ensure`
    # blocks, and the connection-pool :checkin callback below) rely on this
    # not masking whatever exception is already in flight.
    #
    # A plain RESET can itself fail -- most importantly when the request/job
    # raised mid-transaction and Postgres put the connection in "current
    # transaction is aborted, commands ignored until end of transaction
    # block" state. Silently swallowing that failure (the old `rescue nil`)
    # is exactly the bug this method now guards against: the RESET never
    # actually took effect, so the connection would go back to the pool
    # still carrying the previous request's family_id. Instead we log the
    # failure and force a full reconnect, which guarantees a clean Postgres
    # session (no leftover GUC, no aborted transaction) without touching
    # ActiveRecord::ConnectionPool internals directly (see the :checkin
    # callback in config/initializers/rls_connection_safety.rb for why we
    # avoid pool.remove/throw_away! here).
    def reset(connection = ActiveRecord::Base.connection)
      connection.execute("RESET app.current_family_id; RESET app.rls_auth_bypass;")
      true
    rescue => e
      Rails.logger.error(
        "[RlsContext] RESET app.current_family_id failed (#{e.class}: #{e.message}); " \
        "reconnecting to purge session state instead of returning a possibly-poisoned connection to the pool"
      )
      begin
        connection.reconnect!
      rescue => reconnect_error
        Rails.logger.error(
          "[RlsContext] reconnect after failed RESET also failed (#{reconnect_error.class}: #{reconnect_error.message}); " \
          "connection may still be returned to the pool in a bad state"
        )
      end
      false
    end

    def with_family(family_or_id)
      set_family(family_or_id)
      yield
    ensure
      reset
    end

    # Narrow escape hatch for the "casos especiales" in
    # docs/security/rls-design.md: code that genuinely needs to see rows
    # across more than one family (platform-wide metrics jobs, super_admin
    # tooling) once tables are FORCE-protected. Not yet consumed by any RLS
    # policy (see AddRlsSystemContextHelper) -- calling this today only sets
    # a GUC that no policy's USING/WITH CHECK checks. It exists now so the
    # call sites and their audit trail can be reviewed and landed
    # independently of wiring it into any specific policy.
    #
    # Every call is logged with its `reason` and caller so cross-family
    # access is always attributable in the logs -- this is meant to be rare
    # and explicit, not a general-purpose bypass. `reason` is required (no
    # default) so a call site can't opt into system access silently.
    def with_system_access(reason:)
      raise ArgumentError, "with_system_access requires a non-blank reason" if reason.blank?

      caller_location = caller_locations(1, 1)&.first
      Rails.logger.warn(
        "[RlsContext] system access granted: reason=#{reason.inspect} " \
        "caller=#{caller_location&.path}:#{caller_location&.lineno}"
      )
      ActiveRecord::Base.connection.execute("SET app.rls_system_access = 'true'")
      yield
    ensure
      begin
        ActiveRecord::Base.connection.execute("RESET app.rls_system_access")
      rescue => e
        Rails.logger.error(
          "[RlsContext] RESET app.rls_system_access failed (#{e.class}: #{e.message}); reconnecting"
        )
        ActiveRecord::Base.connection.reconnect! rescue nil
      end
    end

    # Bypasses RLS strictly for authentication workflows before a user/family context
    # is established. This is required because tables like `users` and `sessions`
    # must be queried by email or token during login, when `current_family_id` is NULL.
    def with_auth_bypass(reason: nil)
      caller_location = caller_locations(1, 1)&.first
      if reason
        Rails.logger.warn("[RlsContext] auth bypass granted: reason=#{reason.inspect} caller=#{caller_location&.path}:#{caller_location&.lineno}")
      end
      ActiveRecord::Base.connection.execute("SET app.rls_auth_bypass = 'true'")
      yield
    ensure
      begin
        ActiveRecord::Base.connection.execute("RESET app.rls_auth_bypass")
      rescue => e
        Rails.logger.error(
          "[RlsContext] RESET app.rls_auth_bypass failed (#{e.class}: #{e.message}); reconnecting"
        )
        ActiveRecord::Base.connection.reconnect! rescue nil
      end
    end
  end
end
