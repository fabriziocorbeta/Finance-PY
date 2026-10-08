require "test_helper"
require_relative "row_level_security_test"

# Regression test for the pattern that caused real incidents this week
# (statement_imports stuck "pending" forever, accounts syncs silently never
# running): a table has FORCE ROW LEVEL SECURITY but its policy has no
# `OR current_setting('app.rls_auth_bypass', true) = 'true'` clause, so
# RlsContext.with_auth_bypass/with_system_access is a no-op against it.
#
# This walks every FORCE RLS table in the live schema -- not a fixed list --
# so it fails the moment a *future* migration adds FORCE RLS to a new table
# without the bypass clause, instead of waiting for that table's own incident.
class RowLevelSecurityBypassCoverageTest < ActiveSupport::TestCase
  test "every FORCE ROW LEVEL SECURITY table's policy honors app.rls_auth_bypass" do
    forced_tables = ActiveRecord::Base.connection.select_values(<<~SQL)
      SELECT relname FROM pg_class
      WHERE relforcerowsecurity = true AND relkind = 'r'
    SQL

    missing = forced_tables.each_with_object([]) do |table, acc|
      quals = ActiveRecord::Base.connection.select_values(<<~SQL)
        SELECT qual FROM pg_policies WHERE tablename = #{ActiveRecord::Base.connection.quote(table)}
      SQL

      acc << table if quals.empty? || quals.any? { |q| !q.to_s.include?("rls_auth_bypass") }
    end

    assert_empty missing,
      "FORCE RLS tables whose policy doesn't honor app.rls_auth_bypass: #{missing.sort} -- " \
      "RlsContext.with_auth_bypass/with_system_access silently no-ops against these; " \
      "see db/migrate/20261007160000_add_auth_bypass_to_remaining_force_rls_policies.rb for the fix pattern."
  end

  test "accounts policy actually grants access under with_auth_bypass (regression: Basa Capital sync)" do
    family = families(:dylan_family)
    account = family.accounts.first

    RowLevelSecurityTest.ensure_non_superuser_role
    ActiveRecord::Base.connection.execute("SET ROLE app_user")

    found = RlsContext.with_auth_bypass { Account.find_by(id: account.id) }
    assert_equal account.id, found&.id,
      "Account.find_by under with_auth_bypass returned nil -- accounts policy still doesn't honor the bypass GUC"
  ensure
    ActiveRecord::Base.connection.execute("RESET ROLE") rescue nil
  end
end
