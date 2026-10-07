class AllowAuthBypassForStatementImportsRls < ActiveRecord::Migration[7.2]
  # Same pattern, eighth occurrence: messages (20261002140000), chats
  # (20261002150000) and imports/syncs/rules/family_exports (20261003041800)
  # already got this fix. statement_imports got FORCE ROW LEVEL SECURITY on
  # 2026-09-28 (20260928170000) with no bypass clause on its policy.
  #
  # StatementImportsController#create calls
  # StatementParseJob.perform_later(@import.id) -- an id, not a GlobalID, so
  # ActiveJobRowLevelSecurity's #deserialize_arguments_if_needed has nothing
  # to resolve here. The actual break is one step earlier, in
  # #resolve_job_family: it looks up
  # `StatementImport.find_by(id: id)&.family` under RlsContext.with_auth_bypass
  # specifically because no RLS context exists yet to know the real family.
  # That bypass only works if the policy being queried honors the bypass GUC --
  # it didn't for statement_imports, so the lookup silently returned nil, no
  # family got set, and the job ran under RlsContext.reset. The job body's own
  # `StatementImport.find(statement_import_id)` then hit the same
  # family-less FORCE RLS wall, raised ActiveRecord::RecordNotFound, and
  # StatementParseJob's `rescue ActiveRecord::RecordNotFound` (added to handle
  # "import deleted before job ran") swallowed it silently -- so the import
  # sat at status "pending" forever, no error, same symptom as the 2026-10-03
  # incident this migration's siblings were written for.
  TABLE = "statement_imports"

  def up
    policy = "#{TABLE}_family_isolation_policy"
    execute <<-SQL
      DROP POLICY IF EXISTS #{policy} ON #{TABLE};
      CREATE POLICY #{policy} ON #{TABLE}
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

  def down
    policy = "#{TABLE}_family_isolation_policy"
    execute <<-SQL
      DROP POLICY IF EXISTS #{policy} ON #{TABLE};
      CREATE POLICY #{policy} ON #{TABLE}
      USING (family_id = current_family_id())
      WITH CHECK (family_id = current_family_id());
    SQL
  end
end
