class EnableRlsPoliciesDirectTablesOla2EtapaB < ActiveRecord::Migration[7.2]
  # RLS Ola 2 / E1 Etapa B: policies for every table with a direct
  # family_id column that doesn't have a policy yet (see
  # config/rls_inventory.yml, classification: direct) plus the tables this
  # same batch just denormalized family_id onto (classification: indirect,
  # but now direct in shape -- same accountable/entryable INSERT-ordering
  # reasoning as transactions/valuations/receivables).
  #
  # Deliberately ENABLE only, no FORCE: this etapa is policies + tests,
  # not enforcement. FORCE is a separate etapa (owner also is not
  # BYPASSRLS/superuser in prod, so ENABLE-without-FORCE is a behavioral
  # NO-OP in prod today -- the app connects as financespy_app, which owns
  # every one of these tables).
  TABLES = %i[
    binance_items
    coinbase_items
    coinstats_items
    enable_banking_items
    family_documents
    family_exports
    family_merchant_associations
    imports
    indexa_capital_items
    invitations
    llm_usages
    lunchflow_items
    mercury_items
    plaid_items
    simplefin_items
    snaptrade_items
    sophtron_items
    statement_imports
    subscriptions
    syncs
    credit_cards
    cryptos
    depositories
    investments
    loans
    other_assets
    other_liabilities
    properties
    vehicles
    trades
  ].freeze

  def up
    TABLES.each do |table|
      next unless table_exists?(table)

      execute "ALTER TABLE #{table} ENABLE ROW LEVEL SECURITY;"

      execute <<~SQL
        CREATE POLICY #{table}_family_isolation_policy ON #{table}
          FOR ALL
          USING (family_id = current_family_id())
          WITH CHECK (family_id = current_family_id());
      SQL
    end
  end

  def down
    TABLES.each do |table|
      next unless table_exists?(table)

      execute "DROP POLICY IF EXISTS #{table}_family_isolation_policy ON #{table};"
      execute "ALTER TABLE #{table} DISABLE ROW LEVEL SECURITY;"
    end
  end
end
