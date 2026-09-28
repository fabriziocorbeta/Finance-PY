require "test_helper"
require_relative "row_level_security_test"

class RowLevelSecurityOla2EtapaDLote3Test < ActionDispatch::IntegrationTest
  # Etapa D / Lote 3: FORCE puro sobre 47 tablas cuya policy ya existia
  # desde Etapa B (20260923143230/20260923143240). Dos capas:
  #
  # 1. Exhaustiva: confirma que las 47 tablas de la migracion realmente
  #    quedaron con relforcerowsecurity=true en Postgres (atrapa typos u
  #    omisiones en el nombre de tabla sin necesidad de fixtures por tabla).
  # 2. Muestra representativa: aislamiento cross-family real sobre al
  #    menos un caso de cada forma de family_path presente en el lote
  #    (directo, join de 1 salto, join de 2 saltos, join de 3 saltos, y
  #    la tabla root `families` con su bypass explicito).
  FORCED_TABLES = %w[
    addresses binance_accounts binance_items chats coinbase_accounts
    coinbase_items coinstats_accounts coinstats_items data_enrichments
    enable_banking_accounts enable_banking_items families family_documents
    family_exports family_merchant_associations goal_accounts goal_pledges
    import_mappings import_rows imports indexa_capital_accounts
    indexa_capital_items invitations llm_usages lunchflow_accounts
    lunchflow_items mercury_accounts mercury_items messages plaid_accounts
    plaid_items rejected_transfers rule_actions rule_conditions rule_runs
    simplefin_accounts simplefin_items snaptrade_accounts snaptrade_items
    sophtron_accounts sophtron_items statement_imports subscriptions syncs
    taggings tool_calls transfers
  ].freeze

  test "all 47 Etapa D Lote 3 tables have FORCE ROW LEVEL SECURITY set in Postgres" do
    rows = ActiveRecord::Base.connection.execute(<<~SQL)
      SELECT relname, relforcerowsecurity
      FROM pg_class
      WHERE relname IN (#{FORCED_TABLES.map { |t| ActiveRecord::Base.connection.quote(t) }.join(", ")})
        AND relkind = 'r'
    SQL

    found = rows.to_a.index_by { |r| r["relname"] }

    FORCED_TABLES.each do |table|
      assert found.key?(table), "Expected table #{table} to exist in pg_class"
      assert found[table]["relforcerowsecurity"], "Expected #{table} to have FORCE ROW LEVEL SECURITY set"
    end
  end

  test "direct family_id table (family_documents) isolates SELECT under forced RLS" do
    family_a = families(:dylan_family)
    family_b = Family.create!(name: "Etapa D Lote3 Family B", currency: "USD")

    doc_a = FamilyDocument.create!(family: family_a, filename: "doc-a-#{SecureRandom.hex(4)}.pdf")
    doc_b = FamilyDocument.create!(family: family_b, filename: "doc-b-#{SecureRandom.hex(4)}.pdf")

    RowLevelSecurityTest.ensure_non_superuser_role
    ActiveRecord::Base.connection.execute("SET ROLE app_user")
    ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql([ "SET app.current_family_id = ?", family_a.id ])
    )

    assert_nil FamilyDocument.find_by(id: doc_b.id)
    assert_equal doc_a, FamilyDocument.find_by(id: doc_a.id)
  ensure
    ActiveRecord::Base.connection.execute("RESET app.current_family_id") rescue nil
    ActiveRecord::Base.connection.execute("RESET ROLE") rescue nil
  end

  test "1-hop indirect table (plaid_accounts -> plaid_items.family_id) isolates SELECT under forced RLS" do
    family_a = families(:dylan_family)
    family_b = Family.create!(name: "Etapa D Lote3 Family B2", currency: "USD")

    item_a = PlaidItem.create!(family: family_a, name: "Item A", access_token: "tok-a", plaid_id: "lote3-item-a-#{SecureRandom.hex(4)}")
    item_b = PlaidItem.create!(family: family_b, name: "Item B", access_token: "tok-b", plaid_id: "lote3-item-b-#{SecureRandom.hex(4)}")

    account_a = PlaidAccount.create!(plaid_item: item_a, name: "Acct A", plaid_type: "depository", plaid_subtype: "checking", currency: "USD", current_balance: 0, plaid_id: "lote3-acc-a-#{SecureRandom.hex(4)}")
    account_b = PlaidAccount.create!(plaid_item: item_b, name: "Acct B", plaid_type: "depository", plaid_subtype: "checking", currency: "USD", current_balance: 0, plaid_id: "lote3-acc-b-#{SecureRandom.hex(4)}")

    RowLevelSecurityTest.ensure_non_superuser_role
    ActiveRecord::Base.connection.execute("SET ROLE app_user")
    ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql([ "SET app.current_family_id = ?", family_a.id ])
    )

    assert_nil PlaidItem.find_by(id: item_b.id)
    assert_nil PlaidAccount.find_by(id: account_b.id)
    assert_equal item_a, PlaidItem.find_by(id: item_a.id)
    assert_equal account_a, PlaidAccount.find_by(id: account_a.id)
  ensure
    ActiveRecord::Base.connection.execute("RESET app.current_family_id") rescue nil
    ActiveRecord::Base.connection.execute("RESET ROLE") rescue nil
  end

  test "2-hop indirect table (messages -> chats.user_id -> users.family_id) isolates SELECT under forced RLS" do
    family_a = families(:dylan_family)
    chat_a = chats(:one)
    message_a = messages(:chat1_user)

    chat_b = chats(:intro) # user in family :empty
    message_b = Message.create!(chat: chat_b, type: "UserMessage", content: "cross family probe", ai_model: "gpt-4.1")

    RowLevelSecurityTest.ensure_non_superuser_role
    ActiveRecord::Base.connection.execute("SET ROLE app_user")
    ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql([ "SET app.current_family_id = ?", family_a.id ])
    )

    assert_nil Chat.find_by(id: chat_b.id)
    assert_nil Message.find_by(id: message_b.id)
    assert_equal chat_a, Chat.find_by(id: chat_a.id)
    assert_equal message_a, Message.find_by(id: message_a.id)
  ensure
    ActiveRecord::Base.connection.execute("RESET app.current_family_id") rescue nil
    ActiveRecord::Base.connection.execute("RESET ROLE") rescue nil
  end

  test "3-hop indirect table (tool_calls -> messages -> chats -> users.family_id) isolates SELECT under forced RLS" do
    family_a = families(:dylan_family)
    tool_call_a = tool_calls(:one)

    chat_b = chats(:intro)
    message_b = Message.create!(chat: chat_b, type: "AssistantMessage", content: "cross family assistant", ai_model: "gpt-4.1")
    tool_call_b = ToolCall::Function.create!(message: message_b, provider_id: "fc-lote3-b", provider_call_id: "call-lote3-b", function_name: "get_user_info", function_arguments: {}, function_result: "ok")

    RowLevelSecurityTest.ensure_non_superuser_role
    ActiveRecord::Base.connection.execute("SET ROLE app_user")
    ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql([ "SET app.current_family_id = ?", family_a.id ])
    )

    assert_nil ToolCall.find_by(id: tool_call_b.id)
    assert_equal tool_call_a, ToolCall.find_by(id: tool_call_a.id)
  ensure
    ActiveRecord::Base.connection.execute("RESET app.current_family_id") rescue nil
    ActiveRecord::Base.connection.execute("RESET ROLE") rescue nil
  end

  test "families (root) stays isolated under forced RLS but honors app.rls_auth_bypass" do
    family_a = families(:dylan_family)
    family_b = Family.create!(name: "Etapa D Lote3 Family Root B", currency: "USD")

    RowLevelSecurityTest.ensure_non_superuser_role
    ActiveRecord::Base.connection.execute("SET ROLE app_user")
    ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql([ "SET app.current_family_id = ?", family_a.id ])
    )

    assert_nil Family.find_by(id: family_b.id)
    assert_equal family_a, Family.find_by(id: family_a.id)

    ActiveRecord::Base.connection.execute("SET app.rls_auth_bypass = 'true'")
    assert_equal family_b, Family.find_by(id: family_b.id), "Expected platform-level bypass to see cross-family rows"
  ensure
    ActiveRecord::Base.connection.execute("RESET app.rls_auth_bypass") rescue nil
    ActiveRecord::Base.connection.execute("RESET app.current_family_id") rescue nil
    ActiveRecord::Base.connection.execute("RESET ROLE") rescue nil
  end

  test "cross-family INSERT into an indirect table is rejected by WITH CHECK under forced RLS" do
    family_a = families(:dylan_family)
    family_b = Family.create!(name: "Etapa D Lote3 Family C", currency: "USD")
    item_b = PlaidItem.create!(family: family_b, name: "Item B2", access_token: "tok-b2", plaid_id: "lote3-item-b2-#{SecureRandom.hex(4)}")

    RowLevelSecurityTest.ensure_non_superuser_role
    ActiveRecord::Base.connection.execute("SET ROLE app_user")
    ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql([ "SET app.current_family_id = ?", family_a.id ])
    )

    assert_raises(ActiveRecord::StatementInvalid) do
      PlaidAccount.create!(plaid_item: item_b, name: "Rejected", plaid_type: "depository", plaid_subtype: "checking", currency: "USD", current_balance: 0, plaid_id: "lote3-rejected-#{SecureRandom.hex(4)}")
    end
  ensure
    ActiveRecord::Base.connection.execute("RESET app.current_family_id") rescue nil
    ActiveRecord::Base.connection.execute("RESET ROLE") rescue nil
  end
end
