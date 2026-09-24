# frozen_string_literal: true

require "test_helper"

class RlsContextTest < ActiveSupport::TestCase
  test "reset survives an aborted transaction by reconnecting instead of leaving app.current_family_id set" do
    conn = ActiveRecord::Base.connection
    conn.execute(
      ActiveRecord::Base.sanitize_sql([ "SET app.current_family_id = ?", families(:dylan_family).id ])
    )

    # Put the connection into Postgres' "current transaction is aborted,
    # commands ignored until end of transaction block" state at the wire
    # protocol level, bypassing ActiveRecord's transaction management (which
    # would itself issue a ROLLBACK and mask exactly the failure mode we're
    # testing: an ordinary `RESET app.current_family_id` failing because the
    # connection it runs on is mid-aborted-transaction).
    conn.raw_connection.exec("BEGIN")
    begin
      conn.raw_connection.exec("SELECT 1/0")
    rescue PG::Error
      # expected -- the transaction is now aborted
    end

    ok = RlsContext.reset(conn)

    assert_equal false, ok, "reset should report that a plain RESET failed and it had to reconnect"
    assert_predicate(
      conn.select_value("SELECT current_setting('app.current_family_id', true)").to_s,
      :empty?,
      "app.current_family_id must be clear after reset recovers from an aborted transaction"
    )
  ensure
    conn.raw_connection.exec("ROLLBACK") rescue nil
  end

  test "reset on a healthy connection returns true and does not reconnect" do
    conn = ActiveRecord::Base.connection
    conn.execute(
      ActiveRecord::Base.sanitize_sql([ "SET app.current_family_id = ?", families(:dylan_family).id ])
    )

    ok = RlsContext.reset(conn)

    assert_equal true, ok
    assert_predicate conn.select_value("SELECT current_setting('app.current_family_id', true)").to_s, :empty?
  end

  # RLS Ola 2 / E1 Etapa B: with_system_access is the primitive for the
  # "casos especiales" documented in docs/security/rls-design.md. Nothing
  # consumes is_system_context() in a policy yet (see that doc for why), so
  # this only tests the primitive itself: the GUC lifecycle, that it's
  # required to carry a reason, and that it's always reset even on error.
  test "with_system_access sets and resets app.rls_system_access around the block" do
    during_value = nil

    RlsContext.with_system_access(reason: "test coverage") do
      during_value = ActiveRecord::Base.connection.select_value("SELECT current_setting('app.rls_system_access', true)")
    end

    after_value = ActiveRecord::Base.connection.select_value("SELECT current_setting('app.rls_system_access', true)").to_s

    assert_equal "true", during_value
    assert_predicate after_value, :empty?
  end

  test "with_system_access resets app.rls_system_access even when the block raises" do
    assert_raises(RuntimeError) do
      RlsContext.with_system_access(reason: "test coverage") { raise "boom" }
    end

    after_value = ActiveRecord::Base.connection.select_value("SELECT current_setting('app.rls_system_access', true)").to_s
    assert_predicate after_value, :empty?
  end

  test "with_system_access requires a non-blank reason" do
    assert_raises(ArgumentError) { RlsContext.with_system_access(reason: nil) { } }
    assert_raises(ArgumentError) { RlsContext.with_system_access(reason: "") { } }
  end

  test "with_system_access logs the reason and caller" do
    logged = nil
    Rails.logger.stub(:warn, ->(msg) { logged = msg }) do
      RlsContext.with_system_access(reason: "platform_daily_metrics aggregation") { }
    end

    assert_includes logged, "platform_daily_metrics aggregation"
    assert_includes logged, __FILE__
  end

  test "is_system_context() SQL function reflects app.rls_system_access" do
    conn = ActiveRecord::Base.connection

    assert_equal false, conn.select_value("SELECT is_system_context()")

    RlsContext.with_system_access(reason: "test coverage") do
      assert_equal true, conn.select_value("SELECT is_system_context()")
    end

    assert_equal false, conn.select_value("SELECT is_system_context()")
  end
end
