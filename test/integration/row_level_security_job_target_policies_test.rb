require "test_helper"

# Policy-level guard for the four job target tables fixed by
# 20261003041800_allow_auth_bypass_for_job_target_tables_rls.rb: imports, syncs,
# rules and family_exports. Each one is FORCE ROW LEVEL SECURITY, and ActiveJob
# re-resolves their GlobalIDs before any family context is set, so each policy
# has to honor app.rls_auth_bypass (the GUC RlsContext.with_auth_bypass sets).
#
# row_level_security_job_target_tables_test.rb covers the job path end to end.
# These tests check the policies themselves: the policy text in pg_policies, and
# what app_user (NOSUPERUSER NOBYPASSRLS) can see with no context, with another
# family, with its own family, and under the bypass.
class RowLevelSecurityJobTargetPoliciesTest < ActiveSupport::TestCase
  TABLES = %w[imports syncs rules family_exports].freeze
  BYPASS_GUC = "app.rls_auth_bypass"

  def self.ensure_app_user_role
    return if @app_user_role_ensured

    config = ActiveRecord::Base.connection_db_config.configuration_hash
    pg_conn = PG.connect(
      host: config[:host] || "127.0.0.1",
      port: config[:port] || 5432,
      dbname: config[:database],
      user: config[:user] || config[:username],
      password: config[:password]
    )
    pg_conn.exec("SET lock_timeout = '5s';")
    pg_conn.exec("CREATE ROLE app_user WITH LOGIN NOSUPERUSER NOBYPASSRLS;") rescue nil
    pg_conn.exec("GRANT USAGE ON SCHEMA public TO app_user;")
    pg_conn.exec("GRANT SELECT ON #{TABLES.join(", ")} TO app_user;")
    @app_user_role_ensured = true
  ensure
    pg_conn&.close
  end

  setup do
    self.class.ensure_app_user_role
    RlsContext.reset

    @family_a = families(:dylan_family)
    @family_b = Family.create!(name: "Other Family", currency: "USD")

    # syncs.family_id is nullable and the syncs.yml fixture does not set it, so pin
    # it to family A. The other fixtures already belong to dylan_family.
    syncs(:family).update_column(:family_id, @family_a.id)

    @records = {
      "imports" => imports(:pdf),
      "syncs" => syncs(:family),
      "rules" => rules(:one),
      "family_exports" => @family_a.family_exports.create!(status: :pending)
    }
  end

  TABLES.each do |table|
    test "#{table} policy honors app.rls_auth_bypass in USING and WITH CHECK" do
      policy = ActiveRecord::Base.connection.select_one(
        ActiveRecord::Base.sanitize_sql_array([
          "SELECT qual, with_check FROM pg_policies WHERE schemaname = 'public' AND tablename = ? AND policyname = ?",
          table, "#{table}_family_isolation_policy"
        ])
      )

      assert policy, "Expected #{table}_family_isolation_policy on #{table}"
      assert_includes policy["qual"], BYPASS_GUC, "#{table} USING clause must honor #{BYPASS_GUC}"
      assert_includes policy["with_check"], BYPASS_GUC, "#{table} WITH CHECK clause must honor #{BYPASS_GUC}"
    end

    test "#{table} is visible to app_user only for its own family or under the bypass" do
      id = @records.fetch(table).id

      with_app_user do
        assert_equal 0, visible_rows(table, id), "#{table}: no family context and no bypass must hide the row"

        RlsContext.with_family(@family_b) do
          assert_equal 0, visible_rows(table, id), "#{table}: another family must not see the row"
        end

        RlsContext.with_family(@family_a) do
          assert_equal 1, visible_rows(table, id), "#{table}: the owning family must see the row"
        end

        RlsContext.with_auth_bypass do
          assert_equal 1, visible_rows(table, id), "#{table}: #{BYPASS_GUC} must make the row visible"
        end
      end
    end
  end

  private

    def with_app_user
      ActiveRecord::Base.connection.execute("SET ROLE app_user")
      yield
    ensure
      ActiveRecord::Base.connection.execute("RESET ROLE") rescue nil
      RlsContext.reset
    end

    def visible_rows(table, id)
      ActiveRecord::Base.connection.select_value(
        ActiveRecord::Base.sanitize_sql_array([ "SELECT COUNT(*) FROM #{table} WHERE id = ?", id ])
      ).to_i
    end
end
