# frozen_string_literal: true

# Connection-pool safety net for the app.current_family_id RLS GUC.
#
# Problem: RlsContext.set_family issues `SET app.current_family_id` at
# *connection session* scope (not per-transaction). The normal path resets it
# on the way out (Authentication#authenticate_user! sets it,
# RowLevelSecurity#set_postgres_rls_context resets it in an `ensure`,
# ActiveJobRowLevelSecurity resets it after each job). But if the request/job
# raises mid-transaction, or the RESET itself fails (aborted-transaction
# state, connection already dropped by the server, etc.), the connection can
# be checked back into the pool still carrying a previous request's family
# context -- and the *next* request/job to check out that same connection
# would silently run under someone else's RLS scope until it happens to set
# its own family_id.
#
# Fix: hook ActiveRecord's connection-pool checkin/checkout callbacks
# (the same extension point Rails itself uses internally, e.g.
# `set_callback :checkin, :after, :enable_lazy_transactions!` in
# AbstractAdapter) to make it structurally impossible for a connection to
# leave the pool, or be handed out by it, with a stale app.current_family_id.
#
# Why not SET LOCAL / transactional scoping instead of a pool hook: SET LOCAL
# only lasts for the current transaction, but request-scoped RLS context here
# needs to survive across multiple transactions within one request (e.g. a
# controller action that runs several independent `Model.transaction` blocks,
# or streaming responses), and ActiveJobRowLevelSecurity wraps entire job
# `perform` calls, not a single transaction, including jobs with no
# transaction at all around some of their work. Rewriting every RLS-relevant
# request/job to run inside one wrapping transaction just to use SET LOCAL
# would be far more invasive than this pool hook, so we keep SET (session
# scope) and make the pool boundary the hard guarantee instead.
Rails.application.config.to_prepare do
  adapter_class = ActiveRecord::ConnectionAdapters::AbstractAdapter

  # (a) On checkin (connection going back into the pool, whether the
  # request/job succeeded or raised): force a session reset. RlsContext.reset
  # never raises (see its comment) so this can't turn a request failure into
  # a checkin failure -- but it also never silently no-ops, because on
  # failure it reconnects rather than returning the connection dirty.
  adapter_class.set_callback :checkin, :before do
    RlsContext.reset(self)
  end

  # (b) On checkout (connection being handed to a new request/job/thread):
  # defense in depth in case some other code path (a raw
  # `ActiveRecord::Base.connection` grabbed outside our controller/job
  # concerns, a console session, a rake task) set app.current_family_id and
  # never reset it, or in case (a) above ran but a race let another thread
  # observe the connection before checkin's callback finished. Verify the GUC
  # is actually clear before the connection is used; if not, reset again and
  # log loudly since this should never happen given (a).
  adapter_class.set_callback :checkout, :after do
    begin
      leaked_family = select_value("SELECT current_setting('app.current_family_id', true)")
      leaked_auth = select_value("SELECT current_setting('app.rls_auth_bypass', true)")
      if leaked_family.present? || leaked_auth.present?
        Rails.logger.error(
          "[RlsContext] connection checked out of the pool with a leaked app.current_family_id=#{leaked_family.inspect} or app.rls_auth_bypass=#{leaked_auth.inspect}; " \
          "forcing reset. This indicates the :checkin safety net missed a path -- investigate."
        )
        RlsContext.reset(self)
      end
    rescue => e
      # Don't block checkout on this best-effort check (e.g. connection not
      # fully verified yet); the :checkin hook is the primary guarantee.
      Rails.logger.error("[RlsContext] checkout verification failed (#{e.class}: #{e.message})")
    end
  end
end
