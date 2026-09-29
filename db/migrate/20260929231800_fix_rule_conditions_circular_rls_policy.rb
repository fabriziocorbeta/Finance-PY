class FixRuleConditionsCircularRlsPolicy < ActiveRecord::Migration[7.1]
  def up
    # Backfill needs unrestricted read/write access to walk the parent_id
    # chain. This migration runs as the table owner (financespy_app in
    # production); with FORCE already set from #384, even the owner is
    # subject to the (about to be replaced) circular policy. Lifting FORCE
    # for the duration of this single migration transaction is safe -- DDL
    # is transactional in Postgres, so no window of reduced protection is
    # ever exposed to real traffic.
    execute "ALTER TABLE rule_conditions NO FORCE ROW LEVEL SECURITY;"

    # A dedicated column for RLS, deliberately separate from `rule_id`.
    # `rule_id` is NULL on sub-conditions by design (Rule::Condition#rule
    # walks `parent_id` in Ruby to find it -- see that model's comment) and
    # `Rule#conditions` (a plain `has_many`, no explicit scope) relies on
    # that NULL to mean "not top-level": populating `rule_id` on every row
    # would silently pull sub-conditions into `rule.conditions`, breaking
    # `no_nested_compound_conditions`, the rules views, and rule duplication.
    # `root_rule_id` carries the same resolved value on every row (root AND
    # nested) purely for the policy below; nothing in the app reads it.
    add_column :rule_conditions, :root_rule_id, :uuid
    add_index :rule_conditions, :root_rule_id

    execute <<-SQL
      UPDATE rule_conditions
      SET root_rule_id = rule_condition_root_rule_id(id)
      WHERE root_rule_id IS NULL;
    SQL

    # Keep the invariant going forward: every newly inserted or re-parented
    # row gets root_rule_id from its own rule_id (root conditions) or copied
    # from its parent (sub-conditions, at any depth -- the parent row is
    # guaranteed to exist and already have root_rule_id resolved before a
    # child can reference it via the parent_id FK).
    execute <<-SQL
      CREATE OR REPLACE FUNCTION rule_conditions_set_root_rule_id() RETURNS trigger AS $$
      BEGIN
        IF NEW.parent_id IS NULL THEN
          NEW.root_rule_id := NEW.rule_id;
        ELSE
          SELECT root_rule_id INTO NEW.root_rule_id FROM rule_conditions WHERE id = NEW.parent_id;
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;
    SQL

    execute <<-SQL
      DROP TRIGGER IF EXISTS rule_conditions_set_root_rule_id_trigger ON rule_conditions;
      CREATE TRIGGER rule_conditions_set_root_rule_id_trigger
        BEFORE INSERT OR UPDATE OF parent_id, rule_id ON rule_conditions
        FOR EACH ROW EXECUTE FUNCTION rule_conditions_set_root_rule_id();
    SQL

    # Replace the self-referential policy with a plain, non-recursive one.
    # No SECURITY DEFINER, no helper function, no ownership trap: this is
    # exactly the same shape every other direct-family_path table already
    # uses, which is the point.
    execute <<-SQL
      DROP POLICY IF EXISTS rule_conditions_family_isolation_policy ON rule_conditions;
      CREATE POLICY rule_conditions_family_isolation_policy ON rule_conditions
      USING (root_rule_id IN (SELECT id FROM rules WHERE family_id = current_family_id()))
      WITH CHECK (root_rule_id IN (SELECT id FROM rules WHERE family_id = current_family_id()));
    SQL

    # rule_condition_root_rule_id is now unused (it was only ever consumed
    # by the policy just replaced) -- drop it rather than leave dead,
    # already-proven-fragile SECURITY DEFINER code lying around.
    execute "DROP FUNCTION IF EXISTS rule_condition_root_rule_id(uuid);"

    execute "ALTER TABLE rule_conditions FORCE ROW LEVEL SECURITY;"
  end

  def down
    execute "ALTER TABLE rule_conditions NO FORCE ROW LEVEL SECURITY;"

    execute <<-SQL
      CREATE FUNCTION rule_condition_root_rule_id(condition_id uuid) RETURNS uuid
          LANGUAGE plpgsql STABLE SECURITY DEFINER
          SET row_security TO 'off'
          AS $$
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
      $$;
    SQL

    execute "DROP TRIGGER IF EXISTS rule_conditions_set_root_rule_id_trigger ON rule_conditions;"
    execute "DROP FUNCTION IF EXISTS rule_conditions_set_root_rule_id();"

    execute <<-SQL
      DROP POLICY IF EXISTS rule_conditions_family_isolation_policy ON rule_conditions;
      CREATE POLICY rule_conditions_family_isolation_policy ON rule_conditions
      USING (rule_condition_root_rule_id(id) IN (SELECT rules.id FROM rules WHERE rules.family_id = current_family_id()))
      WITH CHECK (rule_condition_root_rule_id(id) IN (SELECT rules.id FROM rules WHERE rules.family_id = current_family_id()));
    SQL

    remove_index :rule_conditions, :root_rule_id
    remove_column :rule_conditions, :root_rule_id

    execute "ALTER TABLE rule_conditions FORCE ROW LEVEL SECURITY;"
  end
end
