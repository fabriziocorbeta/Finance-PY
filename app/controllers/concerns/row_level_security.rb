# frozen_string_literal: true

module RowLevelSecurity
  extend ActiveSupport::Concern

  included do
    around_action :set_postgres_rls_context
  end

  private

    # The real SET happens in Authentication#authenticate_user! once Current.family
    # is known (this around_action runs before authenticate_user! in the filter
    # chain, so Current.family is always nil here — setting it here would just be
    # an extra no-op round-trip). This around_action's job is the RESET safety net:
    # it always fires on the way out, even if the action raises, so a connection
    # checked back into the pool never carries a stale app.current_family_id from
    # this request into whichever request reuses that connection next.
    def set_postgres_rls_context
      yield
    ensure
      RlsContext.reset
    end
end
