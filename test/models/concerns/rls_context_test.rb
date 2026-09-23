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
end
