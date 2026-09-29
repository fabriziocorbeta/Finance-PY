require "test_helper"
require_relative "row_level_security_test"

# Regression test for a production bug found 2026-09-29: GET /api/v1/rules
# threw PG::InsufficientPrivilege ("query would be affected by row-level
# security policy for table rule_conditions") for real traffic.
#
# Root cause: rule_conditions' policy (PR #384) called
# rule_condition_root_rule_id(id), a SECURITY DEFINER function with
# `SET row_security = off` that recursively re-queries rule_conditions
# itself to find the ancestor row holding rule_id (sub-conditions don't
# store it -- see Rule::Condition#rule). SECURITY DEFINER only bypasses RLS
# when the function's *owner* could already see all rows unassisted
# (superuser / BYPASSRLS / table owner without FORCE). In production,
# financespy_app owns both the function and the FORCE'd table and has
# neither BYPASSRLS nor superuser, so `row_security = off` doesn't silently
# bypass anything -- it makes Postgres refuse the query outright with
# exactly this error. Local/CI tests never caught it because table/function
# ownership there belongs to the migrating superuser, which trivially
# satisfies row_security=off regardless of FORCE (see docs/security/
# rls-design.md, "SECURITY DEFINER does not bypass FORCE").
#
# The fix (this PR) denormalizes a `root_rule_id` column onto every
# rule_conditions row (root AND nested), so the policy never needs to
# re-query rule_conditions to evaluate rule_conditions. Deliberately a new
# column, not a repurposed `rule_id`: `rule_id` staying NULL on
# sub-conditions is what `Rule#conditions` (a plain, unscoped has_many)
# relies on to mean "top-level only" -- populating `rule_id` everywhere
# instead of adding a separate column pulls sub-conditions into
# `rule.conditions.count`, breaking
# RulesControllerTest#test_creates_rule_with_nested_conditions (expects 2
# top-level conditions; an earlier version of this fix that reused `rule_id`
# got 4, since sub-conditions started counting too).
class RowLevelSecurityRuleConditionsTest < ActionDispatch::IntegrationTest
  test "rule_conditions has FORCE ROW LEVEL SECURITY set" do
    forced = ActiveRecord::Base.connection.select_value(<<~SQL)
      SELECT relforcerowsecurity FROM pg_class WHERE relname = 'rule_conditions'
    SQL
    assert_equal true, forced
  end

  test "root_rule_id is set automatically on root conditions, sub-conditions, and grandchildren, without touching rule_id" do
    family = families(:dylan_family)
    rule = Rule.create!(family: family, resource_type: "transaction", name: "Root rule id test",
      actions: [ Rule::Action.new(action_type: "exclude_transaction") ])

    root = rule.conditions.create!(condition_type: "compound", operator: "and")
    child = root.sub_conditions.create!(condition_type: "transaction_name", operator: "like", value: "x")

    assert_equal rule.id, root.reload.root_rule_id
    assert_equal rule.id, child.reload.root_rule_id

    # rule_id itself must stay untouched (NULL) on the sub-condition --
    # Rule#conditions (has_many, no scope) relies on that to mean
    # "top-level only". This is the exact invariant the fix must not break.
    assert_nil child.rule_id
    assert_equal 1, rule.conditions.count
  end

  test "family A cannot see family B's rule_conditions via root_rule_id, even for nested sub-conditions, and can see its own" do
    family_a = families(:dylan_family)
    family_b = Family.create!(name: "RLS rule_conditions test family B", currency: "USD")

    rule_a = Rule.create!(family: family_a, resource_type: "transaction", name: "Family A rule",
      actions: [ Rule::Action.new(action_type: "exclude_transaction") ])
    root_a = rule_a.conditions.create!(condition_type: "compound", operator: "and")
    sub_a = root_a.sub_conditions.create!(condition_type: "transaction_name", operator: "like", value: "a")

    rule_b = Rule.create!(family: family_b, resource_type: "transaction", name: "Family B rule",
      actions: [ Rule::Action.new(action_type: "exclude_transaction") ])
    root_b = rule_b.conditions.create!(condition_type: "compound", operator: "and")
    sub_b = root_b.sub_conditions.create!(condition_type: "transaction_name", operator: "like", value: "b")

    RowLevelSecurityTest.ensure_non_superuser_role
    ActiveRecord::Base.connection.execute("SET ROLE app_user")
    ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql([ "SET app.current_family_id = ?", family_a.id ])
    )

    assert_equal root_a, Rule::Condition.find_by(id: root_a.id)
    assert_equal sub_a, Rule::Condition.find_by(id: sub_a.id)
    assert_nil Rule::Condition.find_by(id: root_b.id)
    assert_nil Rule::Condition.find_by(id: sub_b.id),
      "nested sub-condition of another family must stay hidden under the non-recursive root_rule_id policy"
  ensure
    ActiveRecord::Base.connection.execute("RESET app.current_family_id") rescue nil
    ActiveRecord::Base.connection.execute("RESET ROLE") rescue nil
  end

  test "the exact eager-load shape used by Api::V1::RulesController#index works under app_user" do
    family = families(:dylan_family)
    rule = Rule.create!(family: family, resource_type: "transaction", name: "Eager load test rule",
      actions: [ Rule::Action.new(action_type: "exclude_transaction") ])
    root = rule.conditions.create!(condition_type: "compound", operator: "and")
    root.sub_conditions.create!(condition_type: "transaction_name", operator: "like", value: "x")

    RowLevelSecurityTest.ensure_non_superuser_role
    ActiveRecord::Base.connection.execute("SET ROLE app_user")
    ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql([ "SET app.current_family_id = ?", family.id ])
    )

    # Same query shape as Api::V1::RulesController#index (the endpoint that
    # threw PG::InsufficientPrivilege in production).
    loaded = family.rules.includes(:actions, conditions: :sub_conditions).find(rule.id)
    assert_equal 1, loaded.conditions.size
    assert_equal 1, loaded.conditions.first.sub_conditions.size
  ensure
    ActiveRecord::Base.connection.execute("RESET app.current_family_id") rescue nil
    ActiveRecord::Base.connection.execute("RESET ROLE") rescue nil
  end

  test "the old self-referential rule_condition_root_rule_id function is gone" do
    exists = ActiveRecord::Base.connection.select_value(<<~SQL)
      SELECT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'rule_condition_root_rule_id')
    SQL
    assert_equal false, exists,
      "rule_condition_root_rule_id was only ever consumed by the policy this migration replaced -- " \
      "if it still exists, the old circular-RLS code path may still be reachable"
  end
end
