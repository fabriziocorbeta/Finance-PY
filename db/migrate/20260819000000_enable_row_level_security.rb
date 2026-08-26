class EnableRowLevelSecurity < ActiveRecord::Migration[7.2]
  TABLES_WITH_DIRECT_FAMILY_ID = %i[
    accounts
    budgets
    goals
    rules
    categories
    tags
  ].freeze

  INDIRECT_TABLE_POLICIES = {
    merchants: "(family_id = current_family_id() OR family_id IS NULL)",
    entries: "account_id IN (SELECT id FROM accounts WHERE family_id = current_family_id())",
    budget_categories: "budget_id IN (SELECT id FROM budgets WHERE family_id = current_family_id())"
  }.freeze

  # For polymorphic/indirect tables created before entry/account link (transactions, valuations, receivables),
  # USING enforces SELECT/UPDATE/DELETE scoping. WITH CHECK (true) allows INSERT.
  POLYMORPHIC_INDIRECT_POLICIES = {
    transactions: "id IN (SELECT entryable_id FROM entries WHERE entryable_type = 'Transaction' AND account_id IN (SELECT id FROM accounts WHERE family_id = current_family_id()))",
    valuations: "id IN (SELECT entryable_id FROM entries WHERE entryable_type = 'Valuation' AND account_id IN (SELECT id FROM accounts WHERE family_id = current_family_id()))",
    receivables: "id IN (SELECT accountable_id FROM accounts WHERE accountable_type = 'Receivable' AND family_id = current_family_id())"
  }.freeze

  ALL_TABLES = (TABLES_WITH_DIRECT_FAMILY_ID + INDIRECT_TABLE_POLICIES.keys + POLYMORPHIC_INDIRECT_POLICIES.keys).freeze

  def up
    execute <<~SQL
      CREATE OR REPLACE FUNCTION current_family_id() RETURNS uuid AS $$
      BEGIN
        RETURN NULLIF(current_setting('app.current_family_id', true), '')::uuid;
      EXCEPTION
        WHEN invalid_text_representation THEN
          RETURN NULL;
      END;
      $$ LANGUAGE plpgsql STABLE;
    SQL

    ALL_TABLES.each do |table|
      execute "ALTER TABLE #{table} ENABLE ROW LEVEL SECURITY;"
      execute "ALTER TABLE #{table} FORCE ROW LEVEL SECURITY;"
    end

    TABLES_WITH_DIRECT_FAMILY_ID.each do |table|
      policy_condition = "family_id = current_family_id()"
      execute <<~SQL
        CREATE POLICY #{table}_family_isolation_policy ON #{table}
          FOR ALL
          USING (#{policy_condition})
          WITH CHECK (#{policy_condition});
      SQL
    end

    INDIRECT_TABLE_POLICIES.each do |table, policy_condition|
      execute <<~SQL
        CREATE POLICY #{table}_family_isolation_policy ON #{table}
          FOR ALL
          USING (#{policy_condition})
          WITH CHECK (#{policy_condition});
      SQL
    end

    POLYMORPHIC_INDIRECT_POLICIES.each do |table, policy_condition|
      execute <<~SQL
        CREATE POLICY #{table}_family_isolation_policy ON #{table}
          FOR ALL
          USING (#{policy_condition})
          WITH CHECK (true);
      SQL
    end
  end

  def down
    ALL_TABLES.each do |table|
      execute "DROP POLICY IF EXISTS #{table}_family_isolation_policy ON #{table};"
      execute "ALTER TABLE #{table} NO FORCE ROW LEVEL SECURITY;"
      execute "ALTER TABLE #{table} DISABLE ROW LEVEL SECURITY;"
    end

    execute "DROP FUNCTION IF EXISTS current_family_id();"
  end
end
