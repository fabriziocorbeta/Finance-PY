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
        "[RlsContext] RESET app.current_family_id / app.rls_auth_bypass failed (#{e.class}: #{e.message}); " \
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
      already_active = guc_true?("app.rls_system_access")
      ActiveRecord::Base.connection.execute("SET app.rls_system_access = 'true'")
      yield
    ensure
      reset_guc_unless_already_active("app.rls_system_access", already_active)
    end

    # Bypasses RLS strictly for authentication workflows before a user/family context
    # is established. This is required because tables like `users` and `sessions`
    # must be queried by email or token during login, when `current_family_id` is NULL.
    #
    # Reentrant: a call nested inside another with_auth_bypass block (e.g. code
    # in app/controllers/api/v1/base_controller.rb calling into a model method
    # that also wraps itself) leaves the GUC set until the *outermost* block
    # exits, instead of the inner block's `ensure` resetting it early and
    # silently un-bypassing the rest of the outer block's queries.
    def with_auth_bypass(reason: nil)
      caller_location = caller_locations(1, 1)&.first
      if reason
        Rails.logger.warn("[RlsContext] auth bypass granted: reason=#{reason.inspect} caller=#{caller_location&.path}:#{caller_location&.lineno}")
      end
      already_active = guc_true?("app.rls_auth_bypass")
      ActiveRecord::Base.connection.execute("SET app.rls_auth_bypass = 'true'")
      yield
    ensure
      reset_guc_unless_already_active("app.rls_auth_bypass", already_active)
    end

    private

      def guc_true?(guc_name)
        ActiveRecord::Base.connection.select_value(
          ActiveRecord::Base.sanitize_sql([ "SELECT current_setting(?, true)", guc_name ])
        ) == "true"
      rescue
        false
      end

      # Only the outermost with_auth_bypass/with_system_access call resets the
      # GUC. A nested call detected the outer one was already active
      # (already_active) and must leave it set on exit -- resetting here
      # would un-bypass the remainder of the outer block for no reason other
      # than this inner call happening to finish first.
      def reset_guc_unless_already_active(guc_name, already_active)
        return if already_active

        begin
          # guc_name is always one of our own hardcoded GUC names (never
          # user input), so plain interpolation is safe -- RESET doesn't
          # support a bind-parameterized identifier anyway.
          ActiveRecord::Base.connection.execute("RESET #{guc_name}")
        rescue => e
          Rails.logger.error(
            "[RlsContext] RESET #{guc_name} failed (#{e.class}: #{e.message}); reconnecting"
          )
          ActiveRecord::Base.connection.reconnect! rescue nil
        end
      end
  end
end
