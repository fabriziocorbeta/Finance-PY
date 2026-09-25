# frozen_string_literal: true

require "test_helper"
require "yaml"

# RLS Ola 2 / E1 Etapa B, item (3a): a catalog test that walks every real
# table in the schema and fails if either:
#   - the table isn't in config/rls_inventory.yml (a new table landed
#     without anyone deciding its RLS classification), or
#   - a non-"global" table the inventory says already has a policy
#     (policy_present: true) doesn't actually have RLS ENABLEd with at
#     least one pg_policies row (catches drift: someone reverts/edits a
#     migration and forgets to update the inventory, or a policy gets
#     dropped by hand).
#
# FORCE is checked here too, but gated behind ASSERT_FORCE_ROW_LEVEL_SECURITY
# (false this etapa on purpose -- Etapa B is ENABLE + policies only, FORCE is
# a separate etapa). Flip that constant to true once FORCE lands and this
# same test starts enforcing it table by table via the inventory's `force`
# field, no rewrite needed.
class RlsCatalogTest < ActiveSupport::TestCase
  INVENTORY_PATH = Rails.root.join("config/rls_inventory.yml")
  INVENTORY = YAML.load_file(INVENTORY_PATH).freeze

  # Etapa siguiente (FORCE) flips this to true.
  ASSERT_FORCE_ROW_LEVEL_SECURITY = false

  def db_tables
    @db_tables ||= ActiveRecord::Base.connection.select_values(<<~SQL)
      SELECT tablename FROM pg_tables WHERE schemaname = current_schema()
    SQL
  end

  test "every base table in the schema is catalogued in config/rls_inventory.yml" do
    uncatalogued = db_tables - INVENTORY.keys.map(&:to_s)
    assert_empty uncatalogued,
      "tables present in the DB but missing from #{INVENTORY_PATH}: #{uncatalogued.sort} -- " \
      "add an entry (classification/family_path/force/policy_present/notes) before merging."
  end

  test "no stale inventory entries for tables that no longer exist" do
    stale = INVENTORY.keys.map(&:to_s) - db_tables
    assert_empty stale,
      "config/rls_inventory.yml lists tables that don't exist in the schema: #{stale.sort} -- " \
      "remove the entry (or the migration that dropped the table is missing)."
  end

  test "every table's classification is one of the known values" do
    valid = %w[direct direct-nullable indirect auth global storage root]
    invalid = INVENTORY.select { |_t, i| !valid.include?(i["classification"]) }
    assert_empty invalid.keys,
      "unknown classification (expected one of #{valid}): #{invalid.transform_values { |i| i['classification'] }}"
  end

  test "every direct/indirect/root table has a policy after Etapa B" do
    # Etapa B's own completion gate: direct and indirect tables (and the
    # root `families` table) are exactly the classifications Etapa B's
    # migrations were responsible for. auth/storage are deliberately out of
    # scope here -- see docs/security/rls-design.md for why they need a
    # narrower, different-shaped mechanism instead of a blanket
    # family_id-equality policy, and global tables need no policy by
    # definition.
    in_scope = INVENTORY.select { |_t, i| %w[direct direct-nullable indirect root].include?(i["classification"]) }
    missing = in_scope.reject { |_t, i| i["policy_present"] }
    assert_empty missing.keys,
      "direct/indirect/root tables still without a policy: #{missing.keys}"
  end

  test "every table the inventory marks policy_present actually has RLS enabled with a policy in the DB" do
    INVENTORY.each do |table, info|
      next unless info["policy_present"]

      relrowsecurity = ActiveRecord::Base.connection.select_value(
        "SELECT relrowsecurity FROM pg_class WHERE relname = #{ActiveRecord::Base.connection.quote(table)}"
      )
      assert_equal "true", relrowsecurity.to_s,
        "#{table}: config/rls_inventory.yml says policy_present: true but ENABLE ROW LEVEL SECURITY is not set in the DB"

      policy_count = ActiveRecord::Base.connection.select_value(
        "SELECT COUNT(*) FROM pg_policies WHERE tablename = #{ActiveRecord::Base.connection.quote(table)}"
      ).to_i
      assert_operator policy_count, :>, 0,
        "#{table}: config/rls_inventory.yml says policy_present: true but no row exists in pg_policies for it"
    end
  end

  test "global tables have no family-scoping policy (nothing to isolate)" do
    globals = INVENTORY.select { |_t, i| i["classification"] == "global" }
    globals.each_key do |table|
      policy_count = ActiveRecord::Base.connection.select_value(
        "SELECT COUNT(*) FROM pg_policies WHERE tablename = #{ActiveRecord::Base.connection.quote(table)}"
      ).to_i
      assert_equal 0, policy_count,
        "#{table} is classified as global (no family relation) but has an RLS policy -- " \
        "either the classification is wrong or the policy is a mistake."
    end
  end

  test "FORCE ROW LEVEL SECURITY (deferred to the FORCE etapa)" do
    skip "ASSERT_FORCE_ROW_LEVEL_SECURITY is false until the FORCE etapa flips it on" unless ASSERT_FORCE_ROW_LEVEL_SECURITY

    INVENTORY.each do |table, info|
      next if info["classification"] == "global"
      next unless info["force"]

      relforcerowsecurity = ActiveRecord::Base.connection.select_value(
        "SELECT relforcerowsecurity FROM pg_class WHERE relname = #{ActiveRecord::Base.connection.quote(table)}"
      )
      assert_equal "true", relforcerowsecurity.to_s, "#{table}: inventory says force: true but FORCE ROW LEVEL SECURITY is not set"
    end
  end
end
