require "test_helper"
require_relative "row_level_security_test"

# Regression test for the 2026-09-29 production incident: PR #403 forced RLS
# on `families`, which broke login for every user within minutes of deploy.
#
# Root cause: Authentication#authenticate_user! and Api::V1::BaseController
# bootstrapped app.current_family_id from `Current.family&.id`, where
# `Current.family` delegates to the `user.family` AR association -- an
# actual SELECT against `families`. Under FORCE, that SELECT runs before
# app.current_family_id is set for the connection, so the policy's
# `id = current_family_id()` compares against NULL and matches zero rows.
# Current.family was nil for the rest of the request, and every downstream
# family-scoped query failed with NoMethodError on nil.
#
# The ordinary controller/integration test suite never caught this because
# test requests run under the migrator/owner Postgres role, which FORCE
# does not restrict at all (only ENABLE-without-FORCE was already a no-op
# for the app's own connection; see EnableRlsPoliciesDirectTablesOla2EtapaB).
# This test drives the exact mechanism directly under `app_user` with
# `families` FORCEd, independent of the controller test infrastructure.
class RowLevelSecurityFamiliesBootstrapTest < ActionDispatch::IntegrationTest
  test "bootstrapping RLS context from a raw family_id column survives FORCE on families, from the association does not" do
    user = users(:family_admin)
    expected_family_id = user.family_id

    RowLevelSecurityTest.ensure_non_superuser_role
    ActiveRecord::Base.connection.execute("ALTER TABLE families FORCE ROW LEVEL SECURITY;")
    ActiveRecord::Base.connection.execute("SET ROLE app_user")
    # No app.current_family_id set yet -- this is the exact state a fresh
    # request is in before Authentication#authenticate_user! runs.

    # The buggy pattern this incident shipped: Current.family (association)
    # issues a SELECT against families with no context set -> zero rows.
    assert_nil Family.find_by(id: expected_family_id),
      "Sanity check: this documents why the association-based bootstrap broke production -- " \
      "if this ever returns non-nil, the incident's root cause no longer reproduces and this test should be revisited"

    # The fix this incident shipped: family_id is a plain column on the
    # already-loaded `users` row, no families query needed to bootstrap.
    assert_equal expected_family_id, user.family_id

    # Once bootstrapped from the raw column, normal family-scoped access works.
    ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql([ "SET app.current_family_id = ?", expected_family_id ])
    )
    assert_equal families(:dylan_family), Family.find_by(id: expected_family_id)
  ensure
    ActiveRecord::Base.connection.execute("RESET app.current_family_id") rescue nil
    ActiveRecord::Base.connection.execute("RESET ROLE") rescue nil
    ActiveRecord::Base.connection.execute("ALTER TABLE families NO FORCE ROW LEVEL SECURITY;") rescue nil
  end

  test "Authentication#authenticate_user! bootstrap no longer depends on the family association" do
    source = File.read(Rails.root.join("app/controllers/concerns/authentication.rb"))
    assert_match(/RlsContext\.set_family\(Current\.user&\.family_id\)/, source,
      "Expected the RLS bootstrap to use the raw family_id column, not Current.family&.id " \
      "(an AR association that queries `families` before the RLS context exists)")
  end

  test "Api::V1::BaseController bootstrap no longer depends on the family association" do
    source = File.read(Rails.root.join("app/controllers/api/v1/base_controller.rb"))
    assert_match(/RlsContext\.set_family\(@current_user\.family_id\)/, source,
      "Expected the RLS bootstrap to use the raw family_id column, not Current.family&.id " \
      "(an AR association that queries `families` before the RLS context exists)")
  end
end
