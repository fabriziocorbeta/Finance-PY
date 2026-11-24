# frozen_string_literal: true

class EnforceDualLegRlsOnTransfers < ActiveRecord::Migration[7.2]
  # Previously, transfers and rejected_transfers RLS policies checked
  # `current_family_id() IN (SELECT family_id FROM transactions WHERE id = ANY(ARRAY[inflow, outflow]))`,
  # which evaluates TRUE if even ONE leg belongs to the caller's family.
  # Enforce that BOTH inflow_transaction_id AND outflow_transaction_id belong
  # to current_family_id() while preserving app.rls_auth_bypass for system/job
  # GlobalID resolution.
  TABLES = %w[transfers rejected_transfers].freeze

  def up
    TABLES.each do |table|
      policy = "#{table}_family_isolation_policy"
      execute <<~SQL
        DROP POLICY IF EXISTS #{policy} ON #{table};
        CREATE POLICY #{policy} ON #{table}
        USING (
          (
            EXISTS (
              SELECT 1 FROM transactions
              WHERE transactions.id = #{table}.inflow_transaction_id
                AND transactions.family_id = current_family_id()
            )
            AND EXISTS (
              SELECT 1 FROM transactions
              WHERE transactions.id = #{table}.outflow_transaction_id
                AND transactions.family_id = current_family_id()
            )
          )
          OR (current_setting('app.rls_auth_bypass'::text, true) = 'true'::text)
        )
        WITH CHECK (
          (
            EXISTS (
              SELECT 1 FROM transactions
              WHERE transactions.id = #{table}.inflow_transaction_id
                AND transactions.family_id = current_family_id()
            )
            AND EXISTS (
              SELECT 1 FROM transactions
              WHERE transactions.id = #{table}.outflow_transaction_id
                AND transactions.family_id = current_family_id()
            )
          )
          OR (current_setting('app.rls_auth_bypass'::text, true) = 'true'::text)
        );
      SQL
    end
  end

  def down
    TABLES.each do |table|
      policy = "#{table}_family_isolation_policy"
      execute <<~SQL
        DROP POLICY IF EXISTS #{policy} ON #{table};
        CREATE POLICY #{policy} ON #{table}
        USING (
          (current_family_id() IN (
            SELECT transactions.family_id
            FROM transactions
            WHERE transactions.id = ANY (ARRAY[#{table}.inflow_transaction_id, #{table}.outflow_transaction_id])
          ))
          OR (current_setting('app.rls_auth_bypass'::text, true) = 'true'::text)
        )
        WITH CHECK (
          (current_family_id() IN (
            SELECT transactions.family_id
            FROM transactions
            WHERE transactions.id = ANY (ARRAY[#{table}.inflow_transaction_id, #{table}.outflow_transaction_id])
          ))
          OR (current_setting('app.rls_auth_bypass'::text, true) = 'true'::text)
        );
      SQL
    end
  end
end
