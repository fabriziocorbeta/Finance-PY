class EnableRlsForBusinessActiveTables < ActiveRecord::Migration[7.2]
  TABLES_WITH_DIRECT_FAMILY_ID = %i[
    products
    purchase_orders
    sales
    recurring_transactions
  ].freeze

  INDIRECT_TABLE_POLICIES = {
    purchase_order_items: "purchase_order_id IN (SELECT id FROM purchase_orders WHERE family_id = current_family_id())",
    sale_items: "sale_id IN (SELECT id FROM sales WHERE family_id = current_family_id())",
    product_stock_movements: "product_id IN (SELECT id FROM products WHERE family_id = current_family_id())"
  }.freeze

  def up
    TABLES_WITH_DIRECT_FAMILY_ID.each do |table|
      next unless table_exists?(table)

      execute "ALTER TABLE #{table} ENABLE ROW LEVEL SECURITY;"
      execute "ALTER TABLE #{table} FORCE ROW LEVEL SECURITY;"

      policy_condition = "family_id = current_family_id()"
      execute <<~SQL
        CREATE POLICY #{table}_family_isolation_policy ON #{table}
          FOR ALL
          USING (#{policy_condition})
          WITH CHECK (#{policy_condition});
      SQL
    end

    INDIRECT_TABLE_POLICIES.each do |table, policy_condition|
      next unless table_exists?(table)

      execute "ALTER TABLE #{table} ENABLE ROW LEVEL SECURITY;"
      execute "ALTER TABLE #{table} FORCE ROW LEVEL SECURITY;"

      execute <<~SQL
        CREATE POLICY #{table}_family_isolation_policy ON #{table}
          FOR ALL
          USING (#{policy_condition})
          WITH CHECK (#{policy_condition});
      SQL
    end
  end

  def down
    (TABLES_WITH_DIRECT_FAMILY_ID + INDIRECT_TABLE_POLICIES.keys).each do |table|
      next unless table_exists?(table)

      execute "DROP POLICY IF EXISTS #{table}_family_isolation_policy ON #{table};"
      execute "ALTER TABLE #{table} NO FORCE ROW LEVEL SECURITY;"
      execute "ALTER TABLE #{table} DISABLE ROW LEVEL SECURITY;"
    end
  end
end
