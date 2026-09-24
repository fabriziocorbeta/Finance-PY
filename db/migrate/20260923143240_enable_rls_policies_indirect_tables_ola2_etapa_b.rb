class EnableRlsPoliciesIndirectTablesOla2EtapaB < ActiveRecord::Migration[7.2]
  # RLS Ola 2 / E1 Etapa B: join-based policies for tables with no family_id
  # column of their own (config/rls_inventory.yml, classification: indirect)
  # that are safe to scope via a subquery -- i.e. NOT a delegated_type child
  # inserted before its parent exists (those are handled by denormalizing
  # family_id instead; see AddFamilyIdToAccountableAndTradeTables and the
  # tables it covers, plus the pre-existing transactions/valuations/
  # receivables). Every table below is the "many" side of an ordinary
  # belongs_to where the referenced parent row already exists at INSERT
  # time, the same shape as entries.account_id (kept join-based on purpose,
  # see SwitchPolymorphicIndirectRlsToFamilyId's comment).
  #
  # ENABLE only, no FORCE (see EnableRlsPoliciesDirectTablesOla2EtapaB for
  # why that's a deliberate, prod-safe no-op this etapa).
  SINGLE_JOIN = {
    # account_id -> accounts.family_id
    account_providers: "account_id IN (SELECT id FROM accounts WHERE family_id = current_family_id())",
    account_shares: "account_id IN (SELECT id FROM accounts WHERE family_id = current_family_id())",
    balances: "account_id IN (SELECT id FROM accounts WHERE family_id = current_family_id())",
    holdings: "account_id IN (SELECT id FROM accounts WHERE family_id = current_family_id())",

    # *_item_id -> *_items.family_id (items are already direct-policy tables)
    binance_accounts: "binance_item_id IN (SELECT id FROM binance_items WHERE family_id = current_family_id())",
    coinbase_accounts: "coinbase_item_id IN (SELECT id FROM coinbase_items WHERE family_id = current_family_id())",
    coinstats_accounts: "coinstats_item_id IN (SELECT id FROM coinstats_items WHERE family_id = current_family_id())",
    enable_banking_accounts: "enable_banking_item_id IN (SELECT id FROM enable_banking_items WHERE family_id = current_family_id())",
    indexa_capital_accounts: "indexa_capital_item_id IN (SELECT id FROM indexa_capital_items WHERE family_id = current_family_id())",
    lunchflow_accounts: "lunchflow_item_id IN (SELECT id FROM lunchflow_items WHERE family_id = current_family_id())",
    mercury_accounts: "mercury_item_id IN (SELECT id FROM mercury_items WHERE family_id = current_family_id())",
    plaid_accounts: "plaid_item_id IN (SELECT id FROM plaid_items WHERE family_id = current_family_id())",
    simplefin_accounts: "simplefin_item_id IN (SELECT id FROM simplefin_items WHERE family_id = current_family_id())",
    snaptrade_accounts: "snaptrade_item_id IN (SELECT id FROM snaptrade_items WHERE family_id = current_family_id())",
    sophtron_accounts: "sophtron_item_id IN (SELECT id FROM sophtron_items WHERE family_id = current_family_id())",

    # goal_id -> goals.family_id (goals already FORCE'd, direct)
    goal_accounts: "goal_id IN (SELECT id FROM goals WHERE family_id = current_family_id())",
    goal_pledges: "goal_id IN (SELECT id FROM goals WHERE family_id = current_family_id())",

    # import_id -> imports.family_id
    import_mappings: "import_id IN (SELECT id FROM imports WHERE family_id = current_family_id())",
    import_rows: "import_id IN (SELECT id FROM imports WHERE family_id = current_family_id())",

    # rule_id -> rules.family_id (rules already FORCE'd, direct)
    rule_actions: "rule_id IN (SELECT id FROM rules WHERE family_id = current_family_id())",
    rule_runs: "rule_id IN (SELECT id FROM rules WHERE family_id = current_family_id())",

    # tag_id -> tags.family_id (tags already FORCE'd, direct). taggable is
    # polymorphic but today's only consumer (Transaction) doesn't change
    # this: the tag itself already carries the family, no need to also
    # branch on taggable_type.
    taggings: "tag_id IN (SELECT id FROM tags WHERE family_id = current_family_id())",

    # user_id -> users.family_id (users has no RLS policy of its own yet --
    # see docs/security/rls-design.md, "auth" classification -- but a plain
    # subquery against it for a *different* table's policy doesn't need
    # users to have RLS itself).
    chats: "user_id IN (SELECT id FROM users WHERE family_id = current_family_id())",
    mobile_devices: "user_id IN (SELECT id FROM users WHERE family_id = current_family_id())",

    # transactions now has a denormalized family_id (this same batch /
    # 20260902010000) -- both legs of a transfer must belong to the same
    # family by construction, so matching on either id is equivalent to
    # matching on both, and tolerates either column being NULL.
    rejected_transfers: "current_family_id() IN (SELECT family_id FROM transactions WHERE id IN (inflow_transaction_id, outflow_transaction_id))",
    transfers: "current_family_id() IN (SELECT family_id FROM transactions WHERE id IN (inflow_transaction_id, outflow_transaction_id))"
  }.freeze

  # Multi-hop joins (2-3 tables deep). Same INSERT-ordering reasoning as
  # SINGLE_JOIN: in every case here the referenced parent chain already
  # exists at INSERT time (a message can't be created before its chat, a
  # tool_call can't be created before its message).
  MULTI_JOIN = {
    messages: "chat_id IN (SELECT id FROM chats WHERE user_id IN (SELECT id FROM users WHERE family_id = current_family_id()))",
    tool_calls: "message_id IN (SELECT id FROM messages WHERE chat_id IN (SELECT id FROM chats WHERE user_id IN (SELECT id FROM users WHERE family_id = current_family_id())))"
  }.freeze

  # rule_conditions.rule_id is ONLY populated on the top-level condition;
  # nested sub_conditions store parent_id and have rule_id = NULL (see
  # Rule::Condition#rule: "We don't store rule_id on sub_conditions, so
  # 'walk up' to the parent rule"). A plain `rule_id IN (...)` policy would
  # silently hide every nested sub-condition from its own family. Walk the
  # parent_id chain up to the row that does have rule_id set, then check
  # that rule's family -- mirrors the Ruby-level walk-up exactly.
  #
  # This walk has to happen INSIDE a SECURITY DEFINER function, not inline
  # in the policy: a plain recursive CTE referencing rule_conditions from
  # within rule_conditions' own USING clause re-triggers that same policy
  # for every row the CTE reads, and Postgres raises "infinite recursion
  # detected in policy for relation rule_conditions" (confirmed against a
  # live DB while writing this migration -- see
  # test/integration/row_level_security_ola2_etapa_b_test.rb, the
  # "recursive parent_id walk-up" case). SET row_security = off inside the
  # function skips RLS for the function's own queries, breaking the cycle.
  #
  # IMPORTANT for whoever does the FORCE + owner-separation etapa: this
  # function must stay owned by a role that's actually exempt from
  # rule_conditions' RLS (today: the migration-running/table-owning role,
  # which is auto-exempt from an ENABLE-without-FORCE policy). Once
  # rule_conditions is FORCE'd and its owner becomes financespy_app, a
  # SECURITY DEFINER function owned by financespy_app stops being exempt
  # too (FORCE applies to the owner) and this same infinite-recursion error
  # comes back -- see docs/security/rls-design.md, "SECURITY DEFINER does
  # not bypass FORCE" for the general version of this trap. The fix at that
  # point is to own this specific function as a narrow BYPASSRLS helper
  # role, not financespy_app.
  def create_rule_condition_root_rule_id_function
    execute <<~SQL
      CREATE OR REPLACE FUNCTION rule_condition_root_rule_id(condition_id uuid) RETURNS uuid AS $$
      DECLARE
        result uuid;
      BEGIN
        WITH RECURSIVE condition_chain AS (
          SELECT rc.id, rc.parent_id, rc.rule_id
          FROM rule_conditions rc
          WHERE rc.id = condition_id
          UNION ALL
          SELECT parent.id, parent.parent_id, parent.rule_id
          FROM rule_conditions parent
          JOIN condition_chain ON parent.id = condition_chain.parent_id
          WHERE condition_chain.rule_id IS NULL
        )
        SELECT rule_id INTO result FROM condition_chain WHERE rule_id IS NOT NULL LIMIT 1;
        RETURN result;
      END;
      $$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET row_security = off;
    SQL
  end

  RULE_CONDITIONS_POLICY = "rule_condition_root_rule_id(id) IN (SELECT id FROM rules WHERE family_id = current_family_id())"

  # addressable is polymorphic but the only consumer today is Property
  # (config/rls_inventory.yml). If a second addressable type is added later
  # without updating this policy, its rows are simply invisible under RLS
  # (USING returns false) rather than cross-tenant-leaked -- fails closed,
  # but flag it: whoever adds a new addressable type must extend this CASE.
  ADDRESSES_POLICY =
    "(addressable_type = 'Property' AND addressable_id IN (SELECT id FROM properties WHERE family_id = current_family_id()))"

  # enrichable is polymorphic across the 3 Entryable types, all of which
  # now carry a denormalized family_id (transactions/valuations pre-existing,
  # trades added in this same batch).
  DATA_ENRICHMENTS_POLICY = <<~SQL.squish
    (
      (enrichable_type = 'Transaction' AND enrichable_id IN (SELECT id FROM transactions WHERE family_id = current_family_id()))
      OR (enrichable_type = 'Valuation' AND enrichable_id IN (SELECT id FROM valuations WHERE family_id = current_family_id()))
      OR (enrichable_type = 'Trade' AND enrichable_id IN (SELECT id FROM trades WHERE family_id = current_family_id()))
    )
  SQL

  def up
    create_rule_condition_root_rule_id_function

    all_policies = SINGLE_JOIN.merge(MULTI_JOIN)
      .merge(addresses: ADDRESSES_POLICY, data_enrichments: DATA_ENRICHMENTS_POLICY,
        rule_conditions: RULE_CONDITIONS_POLICY)

    all_policies.each do |table, condition|
      next unless table_exists?(table)

      execute "ALTER TABLE #{table} ENABLE ROW LEVEL SECURITY;"
      execute <<~SQL
        CREATE POLICY #{table}_family_isolation_policy ON #{table}
          FOR ALL
          USING (#{condition})
          WITH CHECK (#{condition});
      SQL
    end
  end

  def down
    tables = SINGLE_JOIN.keys + MULTI_JOIN.keys + %i[addresses data_enrichments rule_conditions]
    tables.each do |table|
      next unless table_exists?(table)

      execute "DROP POLICY IF EXISTS #{table}_family_isolation_policy ON #{table};"
      execute "ALTER TABLE #{table} DISABLE ROW LEVEL SECURITY;"
    end

    execute "DROP FUNCTION IF EXISTS rule_condition_root_rule_id(uuid);"
  end
end
