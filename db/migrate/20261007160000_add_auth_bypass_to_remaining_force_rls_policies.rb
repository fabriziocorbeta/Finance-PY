class AddAuthBypassToRemainingForceRlsPolicies < ActiveRecord::Migration[7.2]
  # Same pattern fixed one table at a time all night (messages, chats,
  # imports/syncs/rules/family_exports, statement_imports): FORCE ROW LEVEL
  # SECURITY rolled out across 92 tables in Etapa D (lotes 1-4, PRs #401/#403
  # and others, merged 2026-09-28), but only a handful of those 92 policies
  # got the `OR current_setting('app.rls_auth_bypass', true) = 'true'`
  # clause that RlsContext.with_auth_bypass/with_system_access depend on.
  # Every other FORCE RLS table silently ignores that bypass -- any code
  # path that needs to look something up before a real family context
  # exists (job family resolution, system jobs, admin tooling) gets zero
  # rows back, not an error. Confirmed bugs from exactly this gap tonight:
  # statement_imports (stuck "pending" imports) and accounts (Account.find
  # inside with_auth_bypass returning nil, syncs silently never running).
  # This migration closes the gap for all 76 remaining tables in one pass.
  #
  # Each table's policy keeps its EXACT existing USING/WITH CHECK
  # expression -- read live from pg_policies, not retyped here. Many of
  # these are multi-table subqueries (e.g. account_providers checks
  # `account_id IN (SELECT id FROM accounts WHERE family_id = ...)`), and
  # hand-transcribing 76 of those is exactly how a typo gets into a
  # security policy. Only the trailing `OR <bypass>` is added (up) or
  # removed (down); #down undoes precisely what #up wrote by stripping the
  # same suffix back off the live (now-bypassed) definition, so it can't
  # drift from a separately maintained copy of the "original" text.
  TABLES = %w[
    account_providers account_shares accounts addresses balances
    binance_accounts binance_items budget_categories budgets categories
    coinbase_accounts coinbase_items coinstats_accounts coinstats_items
    consents credit_cards cryptos data_enrichments depositories
    enable_banking_accounts enable_banking_items entries family_documents
    family_merchant_associations fleet_vehicles fuel_log_lines fuel_logs
    goal_accounts goal_pledges goals holdings import_mappings import_rows
    indexa_capital_accounts indexa_capital_items investments llm_usages
    loans lunchflow_accounts lunchflow_items merchants mercury_accounts
    mercury_items other_assets other_liabilities plaid_accounts plaid_items
    product_stock_movements products properties purchase_order_items
    purchase_orders receivables recurring_transactions rejected_transfers
    rule_actions rule_conditions rule_runs sale_items sales
    simplefin_accounts simplefin_items snaptrade_accounts snaptrade_items
    sophtron_accounts sophtron_items subscriptions taggings tags tool_calls
    trades transactions transfers valuations vehicles versions
  ].freeze

  BYPASS_CLAUSE = "current_setting('app.rls_auth_bypass', true) = 'true'"
  # Exact shape Postgres deparses BYPASS_CLAUSE into once it round-trips
  # through a CREATE POLICY (casts added, whitespace normalized). #down
  # matches this, not the literal above, because this is what's actually
  # sitting in pg_policies after #up ran.
  NORMALIZED_BYPASS_SUFFIX =
    / OR \(current_setting\('app\.rls_auth_bypass'::text,\s*true\)\s*=\s*'true'::text\)\z/.freeze

  def up
    TABLES.each { |table| add_bypass(table) }
  end

  def down
    TABLES.each { |table| remove_bypass(table) }
  end

  private

    def add_bypass(table)
      policy = "#{table}_family_isolation_policy"
      qual, check = policy_definition(table, policy)
      return if qual.nil? # policy not found under the expected name -- leave alone
      return if qual.include?("rls_auth_bypass") # already fixed, idempotent

      new_qual  = "(#{qual}) OR (#{BYPASS_CLAUSE})"
      new_check = check.present? ? "(#{check}) OR (#{BYPASS_CLAUSE})" : new_qual

      execute <<-SQL
      DROP POLICY IF EXISTS #{policy} ON #{table};
      CREATE POLICY #{policy} ON #{table}
      USING (#{new_qual})
      WITH CHECK (#{new_check});
    SQL
    end

    def remove_bypass(table)
      policy = "#{table}_family_isolation_policy"
      qual, check = policy_definition(table, policy)
      return if qual.nil?
      return unless qual.include?("rls_auth_bypass")

      stripped_qual  = strip_bypass(qual)
      stripped_check = check.present? ? strip_bypass(check) : stripped_qual

      execute <<-SQL
      DROP POLICY IF EXISTS #{policy} ON #{table};
      CREATE POLICY #{policy} ON #{table}
      USING (#{stripped_qual})
      WITH CHECK (#{stripped_check});
    SQL
    end

    def policy_definition(table, policy)
      conn = ActiveRecord::Base.connection
      # No schemaname filter: prod runs everything under schema `financespy`,
      # dev/test under `public`. Hardcoding either one made #up silently
      # match zero rows -- and therefore do nothing at all -- in whichever
      # environment doesn't use that literal schema name. Confirmed single-
      # schema per environment (no pg_tables/pg_policies rows under any other
      # schema in either), so matching on table+policy name alone is
      # unambiguous and portable.
      row = conn.select_one(<<-SQL)
      SELECT qual, with_check
      FROM pg_policies
      WHERE tablename = #{conn.quote(table)}
        AND policyname = #{conn.quote(policy)}
    SQL
      return [ nil, nil ] if row.nil?

      [ row["qual"], row["with_check"] ]
    end

    # expr is always, once #up has run, "(<original> OR (current_setting(...)))" --
    # Postgres's own canonical deparse of whatever #up wrote. Peel the OR
    # wrapper to recover exactly the <original> pg_policies would show if the
    # bypass clause had never been added.
    def strip_bypass(expr)
      inner = expr.sub(/\A\((.*)\)\z/m, '\1')
      inner.sub(NORMALIZED_BYPASS_SUFFIX, "")
    end
end
