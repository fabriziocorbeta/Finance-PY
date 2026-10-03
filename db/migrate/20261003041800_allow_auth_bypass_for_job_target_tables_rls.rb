class AllowAuthBypassForJobTargetTablesRls < ActiveRecord::Migration[7.2]
  # Same pattern, fourth/fifth/sixth/seventh occurrence: messages (20261002140000)
  # and chats (20261002150000) already got this fix after the AI chat went
  # unanswered. imports, syncs, rules and family_exports are each under FORCE
  # ROW LEVEL SECURITY (20260928170000) with no bypass clause, and each is
  # the GlobalID target of a perform_later(record) call that passes the
  # ActiveRecord object directly rather than its id:
  #
  #   - ProcessPdfJob.perform_later(pdf_import)       -> imports
  #   - SyncJob.perform_later(sync)                   -> syncs
  #   - RuleJob.perform_later(rule)                   -> rules
  #   - FamilyDataExportJob.perform_later(export)     -> family_exports
  #
  # ActiveJob re-resolves that GlobalID in #deserialize_arguments_if_needed,
  # which runs before ActiveJobRowLevelSecurity's around_perform sets any RLS
  # context; that concern already wraps deserialization in
  # RlsContext.with_auth_bypass (29d385e), but the bypass only works if the
  # policy being queried actually honors the bypass GUC. It didn't for any of
  # these four tables. Confirmed directly in production: a real PDF upload on
  # 2026-10-03 got stuck at "Procesando tu PDF" forever, worker logs showing
  # the identical ActiveJob::DeserializationError pattern as the chat bug.
  TABLES = %w[imports syncs rules family_exports].freeze

  def up
    TABLES.each do |table|
      policy = "#{table}_family_isolation_policy"
      execute <<-SQL
        DROP POLICY IF EXISTS #{policy} ON #{table};
        CREATE POLICY #{policy} ON #{table}
        USING (
          family_id = current_family_id()
          OR current_setting('app.rls_auth_bypass', true) = 'true'
        )
        WITH CHECK (
          family_id = current_family_id()
          OR current_setting('app.rls_auth_bypass', true) = 'true'
        );
      SQL
    end
  end

  def down
    TABLES.each do |table|
      policy = "#{table}_family_isolation_policy"
      execute <<-SQL
        DROP POLICY IF EXISTS #{policy} ON #{table};
        CREATE POLICY #{policy} ON #{table}
        USING (family_id = current_family_id())
        WITH CHECK (family_id = current_family_id());
      SQL
    end
  end
end
