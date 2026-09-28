class ForceRlsForEtapaDLote3 < ActiveRecord::Migration[7.2]
  # RLS Ola 2 / Etapa D — Lote 3: FORCE para toda tabla de
  # config/rls_inventory.yml con policy_present: true y force: false que
  # no fue cubierta por PR #401 (accountables/trades/account extensions).
  # Todas ya tienen ENABLE + CREATE POLICY desde Etapa B
  # (20260923143230/20260923143240); este lote es enforcement puro, sin
  # cambios de policy.
  TABLES = %i[
    addresses
    binance_accounts
    binance_items
    chats
    coinbase_accounts
    coinbase_items
    coinstats_accounts
    coinstats_items
    data_enrichments
    enable_banking_accounts
    enable_banking_items
    families
    family_documents
    family_exports
    family_merchant_associations
    goal_accounts
    goal_pledges
    import_mappings
    import_rows
    imports
    indexa_capital_accounts
    indexa_capital_items
    invitations
    llm_usages
    lunchflow_accounts
    lunchflow_items
    mercury_accounts
    mercury_items
    messages
    plaid_accounts
    plaid_items
    rejected_transfers
    rule_actions
    rule_conditions
    rule_runs
    simplefin_accounts
    simplefin_items
    snaptrade_accounts
    snaptrade_items
    sophtron_accounts
    sophtron_items
    statement_imports
    subscriptions
    syncs
    taggings
    tool_calls
    transfers
  ].freeze

  def up
    TABLES.each do |table|
      execute "ALTER TABLE #{table} FORCE ROW LEVEL SECURITY;"
    end
  end

  def down
    TABLES.each do |table|
      execute "ALTER TABLE #{table} NO FORCE ROW LEVEL SECURITY;"
    end
  end
end
