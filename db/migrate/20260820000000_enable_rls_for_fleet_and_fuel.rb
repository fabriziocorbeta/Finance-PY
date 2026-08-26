class EnableRlsForFleetAndFuel < ActiveRecord::Migration[7.2]
  TABLES_WITH_DIRECT_FAMILY_ID = %i[
    fleet_vehicles
  ].freeze

  INDIRECT_TABLE_POLICIES = {
    fuel_logs: "fleet_vehicle_id IN (SELECT id FROM fleet_vehicles WHERE family_id = current_family_id())",
    fuel_log_lines: "fuel_log_id IN (SELECT id FROM fuel_logs WHERE fleet_vehicle_id IN (SELECT id FROM fleet_vehicles WHERE family_id = current_family_id()))"
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
