require "test_helper"
require_relative "row_level_security_test"

# Regression test for a bug found while investigating the families P0
# (2026-09-29): Api::V1::BaseController#authenticate_api_key called
# @api_key.update_last_used! BEFORE setup_current_context_for_api set
# app.current_family_id. api_keys is FORCE ROW LEVEL SECURITY'd (PR #392),
# and its policy requires app.current_family_id or app.rls_auth_bypass to be
# set -- neither is true at that point in the request. update_column doesn't
# check affected rowcount, so the UPDATE silently matched zero rows and
# last_used_at never advanced for any API-key-authenticated request.
#
# The ordinary controller test suite never caught this because it runs
# under the migrator/owner Postgres role, which FORCE does not restrict.
# This test drives the exact mechanism directly under `app_user`.
class RowLevelSecurityApiKeyTouchBootstrapTest < ActionDispatch::IntegrationTest
  test "update_last_used! is a no-op under app_user before family context is set, succeeds after" do
    user = users(:family_admin)
    user.api_keys.active.destroy_all
    api_key = ApiKey.create!(
      user: user,
      name: "RLS bootstrap test key",
      scopes: [ "read_write" ],
      display_key: "rls_bootstrap_test_#{SecureRandom.hex(8)}"
    )
    original_last_used_at = api_key.last_used_at

    RowLevelSecurityTest.ensure_non_superuser_role
    ActiveRecord::Base.connection.execute("SET ROLE app_user")

    # No app.current_family_id set yet -- the exact state authenticate_api_key
    # is in right after ApiKey.find_by_value returns (that lookup uses its own
    # with_auth_bypass block, already reset by the time it returns). Reading
    # the row back also needs bypass here -- SELECT is gated by the same
    # policy as UPDATE -- so the check itself must go through with_auth_bypass;
    # it isn't part of what's under test.
    api_key.update_last_used!
    persisted_last_used_at = RlsContext.with_auth_bypass(reason: "test_verify") { api_key.reload.last_used_at }
    assert_equal original_last_used_at, persisted_last_used_at,
      "Sanity check: this documents the bug -- an UPDATE against a FORCE-protected " \
      "table with no family context and no auth_bypass silently matches zero rows. " \
      "If this ever fails, the bug no longer reproduces and this test should be revisited."

    # The fix: once app.current_family_id is set (as setup_current_context_for_api
    # now does before update_last_used! is called), the UPDATE actually lands.
    ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql([ "SET app.current_family_id = ?", user.family_id ])
    )
    api_key.update_last_used!
    persisted_last_used_at = RlsContext.with_auth_bypass(reason: "test_verify") { api_key.reload.last_used_at }
    assert_not_equal original_last_used_at, persisted_last_used_at
  ensure
    ActiveRecord::Base.connection.execute("RESET app.current_family_id") rescue nil
    ActiveRecord::Base.connection.execute("RESET ROLE") rescue nil
  end

  test "authenticate_api_key calls update_last_used! after setup_current_context_for_api, not before" do
    source = File.read(Rails.root.join("app/controllers/api/v1/base_controller.rb"))
    method_body = source[/def authenticate_api_key.*?\n    end/m]
    assert method_body, "authenticate_api_key method not found"

    setup_index = method_body.index("setup_current_context_for_api")
    touch_index = method_body.index("update_last_used!")
    assert setup_index && touch_index, "expected both calls to be present"
    assert setup_index < touch_index,
      "update_last_used! must run after setup_current_context_for_api sets " \
      "app.current_family_id -- api_keys is FORCE RLS'd and the UPDATE has no auth_bypass"
  end
end
