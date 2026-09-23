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
      connection.execute("RESET app.current_family_id")
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
  end
end
