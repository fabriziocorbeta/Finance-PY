require "test_helper"
require_relative "row_level_security_test"

# Regression test: StatementImportsController#create calls
# StatementParseJob.perform_later(@import.id) -- an id, not a GlobalID.
# ActiveJobRowLevelSecurity's #resolve_job_family looks up
# `StatementImport.find_by(id: id)&.family` under RlsContext.with_auth_bypass
# to learn the family *before* any RLS context exists. That bypass only works
# if the table's policy honors the bypass GUC -- it didn't for
# statement_imports (FORCE ROW LEVEL SECURITY since 20260928170000, no bypass
# clause), so the lookup silently returned nil, the job ran under
# RlsContext.reset, and its own `StatementImport.find(statement_import_id)`
# raised ActiveRecord::RecordNotFound -- which StatementParseJob's
# `rescue ActiveRecord::RecordNotFound` (meant for "import deleted before job
# ran") swallowed. The import sat at status "pending" forever, no error.
class RowLevelSecurityStatementParseJobTest < ActiveSupport::TestCase
  test "statement_imports has FORCE ROW LEVEL SECURITY set" do
    forced = ActiveRecord::Base.connection.select_value(<<~SQL)
      SELECT relforcerowsecurity FROM pg_class WHERE relname = 'statement_imports'
    SQL
    assert_equal true, forced, "Expected statement_imports to have FORCE ROW LEVEL SECURITY set"
  end

  test "resolve_job_family resolves the import owner's family for StatementParseJob under real FORCE RLS" do
    user = users(:family_admin)
    import = StatementImport.create!(family: user.family, user: user, bank_name: "Test Bank")

    RowLevelSecurityTest.ensure_non_superuser_role
    ActiveRecord::Base.connection.execute("SET ROLE app_user")

    job = StatementParseJob.new(import.id)
    family = RlsContext.with_auth_bypass { job.send(:resolve_job_family) }

    assert_equal user.family_id, family&.id,
      "Expected resolve_job_family to find the import owner's family, not nil"
  ensure
    ActiveRecord::Base.connection.execute("RESET ROLE") rescue nil
  end

  test "StatementParseJob finds its import (not RecordNotFound) once the family resolves under real FORCE RLS" do
    user = users(:family_admin)
    import = StatementImport.create!(family: user.family, user: user, bank_name: "Test Bank")

    RowLevelSecurityTest.ensure_non_superuser_role
    ActiveRecord::Base.connection.execute("SET ROLE app_user")

    family = RlsContext.with_auth_bypass { StatementImport.find_by(id: import.id)&.family }

    assert_nothing_raised do
      RlsContext.with_family(family) do
        StatementImport.find(import.id)
      end
    end
  ensure
    ActiveRecord::Base.connection.execute("RESET ROLE") rescue nil
  end
end
