class AddRlsSystemContextHelper < ActiveRecord::Migration[7.2]
  # Prep for the "casos especiales" mechanism documented in
  # docs/security/rls-design.md (system mode for genuinely cross-family
  # jobs -- platform metrics, super_admin tooling). This migration ONLY
  # adds the SQL primitive; it is not referenced by any policy's USING/WITH
  # CHECK clause yet, so it is a behavioral no-op today. Wiring it into a
  # specific table's policy is a deliberate, narrow, reviewed change to
  # make per case -- see the design doc for why (a blanket "OR
  # is_system_context()" on every policy would defeat the whole point of
  # FORCE once that etapa lands).
  #
  # is_system_context() mirrors current_family_id()'s shape (STABLE, reads
  # a session GUC, tolerant of the GUC being unset). RlsContext.with_system_access
  # (app/models/concerns/rls_context.rb) is the only intended caller of the
  # underlying SET -- app code should never SET app.rls_system_access
  # directly.
  def up
    execute <<~SQL
      CREATE OR REPLACE FUNCTION is_system_context() RETURNS boolean AS $$
      BEGIN
        RETURN COALESCE(NULLIF(current_setting('app.rls_system_access', true), ''), 'false')::boolean;
      EXCEPTION
        WHEN invalid_text_representation THEN
          RETURN false;
      END;
      $$ LANGUAGE plpgsql STABLE;
    SQL
  end

  def down
    execute "DROP FUNCTION IF EXISTS is_system_context();"
  end
end
