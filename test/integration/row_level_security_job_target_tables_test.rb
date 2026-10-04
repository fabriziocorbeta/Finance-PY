require "test_helper"
require_relative "row_level_security_test"

# Regression test for a real production incident (2026-10-03): the new PDF
# import button in the AI chat got stuck forever at "Procesando tu PDF".
# `imports` (and, by the same pattern, `syncs`, `rules`, `family_exports`)
# got FORCE ROW LEVEL SECURITY on 2026-09-28 (20260928170000) with no bypass
# clause on their policies. ProcessPdfJob.perform_later(pdf_import) /
# SyncJob.perform_later(sync) / RuleJob.perform_later(rule) /
# FamilyDataExportJob.perform_later(export) each pass the record as an
# object, which ActiveJob serializes as a GlobalID and re-resolves in
# #deserialize_arguments_if_needed -- a step that runs before
# ActiveJobRowLevelSecurity's around_perform sets any RLS context. That
# concern already wraps deserialization in RlsContext.with_auth_bypass
# (29d385e), but the bypass only works if the policy itself honors the GUC.
# It didn't for any of these four tables -- confirmed directly in
# production worker logs for a real PDF upload, raising the identical
# ActiveJob::DeserializationError pattern as the chat bug (426-429).
class RowLevelSecurityJobTargetTablesTest < ActiveSupport::TestCase
  %w[imports syncs rules family_exports].each do |table|
    test "#{table} has FORCE ROW LEVEL SECURITY set" do
      forced = ActiveRecord::Base.connection.select_value(<<~SQL)
        SELECT relforcerowsecurity FROM pg_class WHERE relname = '#{table}'
      SQL
      assert_equal true, forced, "Expected #{table} to have FORCE ROW LEVEL SECURITY set"
    end
  end

  test "ProcessPdfJob deserializes its PdfImport GlobalID arg under real FORCE RLS" do
    family = families(:dylan_family)
    account = accounts(:depository)
    pdf_import = family.imports.create!(
      type: "PdfImport",
      account: account,
      status: "pending",
      document_type: "bank_statement"
    )

    assert_job_deserializes_under_force_rls(ProcessPdfJob.new(pdf_import))
  end

  test "SyncJob deserializes its Sync GlobalID arg under real FORCE RLS" do
    sync = syncs(:family)

    assert_job_deserializes_under_force_rls(SyncJob.new(sync, balances_only: false))
  end

  test "RuleJob deserializes its Rule GlobalID arg under real FORCE RLS" do
    rule = rules(:one)

    assert_job_deserializes_under_force_rls(RuleJob.new(rule))
  end

  test "FamilyDataExportJob deserializes its FamilyExport GlobalID arg under real FORCE RLS" do
    family = families(:dylan_family)
    export = family.family_exports.create!(status: :pending)

    assert_job_deserializes_under_force_rls(FamilyDataExportJob.new(export))
  end

  # Lista de tablas justificadas que tienen relforcerowsecurity = true
  # pero NO tienen bypass de RLS porque solo se usan luego de fijar el contexto de familia
  JUSTIFIED_NO_BYPASS = {
    "account_providers" => "Solo se usa después de fijar el contexto de familia",
    "account_shares" => "Solo se usa después de fijar el contexto de familia",
    "addresses" => "Solo se usa después de fijar el contexto de familia",
    "balances" => "Solo se usa después de fijar el contexto de familia",
    "binance_accounts" => "Solo se usa después de fijar el contexto de familia",
    "budget_categories" => "Solo se usa después de fijar el contexto de familia",
    "budgets" => "Solo se usa después de fijar el contexto de familia",
    "categories" => "Solo se usa después de fijar el contexto de familia",
    "coinbase_accounts" => "Solo se usa después de fijar el contexto de familia",
    "coinstats_accounts" => "Solo se usa después de fijar el contexto de familia",
    "consents" => "Solo se usa después de fijar el contexto de familia",
    "credit_cards" => "Solo se usa después de fijar el contexto de familia",
    "cryptos" => "Solo se usa después de fijar el contexto de familia",
    "data_enrichments" => "Solo se usa después de fijar el contexto de familia",
    "depositories" => "Solo se usa después de fijar el contexto de familia",
    "enable_banking_accounts" => "Solo se usa después de fijar el contexto de familia",
    "entries" => "Solo se usa después de fijar el contexto de familia",
    "family_documents" => "Solo se usa después de fijar el contexto de familia",
    "family_merchant_associations" => "Solo se usa después de fijar el contexto de familia",
    "fleet_vehicles" => "Solo se usa después de fijar el contexto de familia",
    "fuel_log_lines" => "Solo se usa después de fijar el contexto de familia",
    "fuel_logs" => "Solo se usa después de fijar el contexto de familia",
    "goal_accounts" => "Solo se usa después de fijar el contexto de familia",
    "goal_pledges" => "Solo se usa después de fijar el contexto de familia",
    "goals" => "Solo se usa después de fijar el contexto de familia",
    "holdings" => "Solo se usa después de fijar el contexto de familia",
    "import_mappings" => "Solo se usa después de fijar el contexto de familia",
    "import_rows" => "Solo se usa después de fijar el contexto de familia",
    "investments" => "Solo se usa después de fijar el contexto de familia",
    "llm_usages" => "Solo se usa después de fijar el contexto de familia",
    "loans" => "Solo se usa después de fijar el contexto de familia",
    "lunchflow_accounts" => "Solo se usa después de fijar el contexto de familia",
    "merchants" => "Solo se usa después de fijar el contexto de familia",
    "mercury_accounts" => "Solo se usa después de fijar el contexto de familia",
    "other_assets" => "Solo se usa después de fijar el contexto de familia",
    "other_liabilities" => "Solo se usa después de fijar el contexto de familia",
    "plaid_accounts" => "Solo se usa después de fijar el contexto de familia",
    "product_stock_movements" => "Solo se usa después de fijar el contexto de familia",
    "products" => "Solo se usa después de fijar el contexto de familia",
    "properties" => "Solo se usa después de fijar el contexto de familia",
    "purchase_order_items" => "Solo se usa después de fijar el contexto de familia",
    "purchase_orders" => "Solo se usa después de fijar el contexto de familia",
    "receivables" => "Solo se usa después de fijar el contexto de familia",
    "recurring_transactions" => "Solo se usa después de fijar el contexto de familia",
    "rejected_transfers" => "Solo se usa después de fijar el contexto de familia",
    "rule_actions" => "Solo se usa después de fijar el contexto de familia",
    "rule_conditions" => "Solo se usa después de fijar el contexto de familia",
    "rule_runs" => "Solo se usa después de fijar el contexto de familia",
    "sale_items" => "Solo se usa después de fijar el contexto de familia",
    "sales" => "Solo se usa después de fijar el contexto de familia",
    "simplefin_accounts" => "Solo se usa después de fijar el contexto de familia",
    "sophtron_accounts" => "Solo se usa después de fijar el contexto de familia",
    "statement_imports" => "Solo se usa después de fijar el contexto de familia",
    "subscriptions" => "Solo se usa después de fijar el contexto de familia",
    "taggings" => "Solo se usa después de fijar el contexto de familia",
    "tags" => "Solo se usa después de fijar el contexto de familia",
    "tool_calls" => "Solo se usa después de fijar el contexto de familia",
    "trades" => "Solo se usa después de fijar el contexto de familia",
    "transactions" => "Solo se usa después de fijar el contexto de familia",
    "transfers" => "Solo se usa después de fijar el contexto de familia",
    "valuations" => "Solo se usa después de fijar el contexto de familia",
    "vehicles" => "Solo se usa después de fijar el contexto de familia",
    "versions" => "Solo se usa después de fijar el contexto de familia",
  }

  test "all FORCE RLS tables have app.rls_auth_bypass clause or are explicitly justified" do
    tables_without_bypass = ActiveRecord::Base.connection.execute(<<~SQL).to_a.map { |r| r["table_name"] }
      SELECT DISTINCT c.relname AS table_name
      FROM pg_class c
      WHERE c.relforcerowsecurity = true
        AND NOT EXISTS (
          SELECT 1 FROM pg_policy p
          WHERE p.polrelid = c.oid
            AND (
              (p.polqual IS NOT NULL AND pg_get_expr(p.polqual, p.polrelid) ILIKE '%app.rls_auth_bypass%')
              OR
              (p.polwithcheck IS NOT NULL AND pg_get_expr(p.polwithcheck, p.polrelid) ILIKE '%app.rls_auth_bypass%')
            )
        )
    SQL

    unjustified_tables = tables_without_bypass - JUSTIFIED_NO_BYPASS.keys

    assert_empty unjustified_tables.sort,
      "Found FORCE RLS tables without app.rls_auth_bypass clause that are not justified: #{unjustified_tables.sort.join(', ')}. " \
      "If a table is an ActiveJob argument, it needs a bypass to survive GlobalID deserialization. " \
      "If it's strictly accessed after context is set, add it to JUSTIFIED_NO_BYPASS with a comment."
  end

  private

    def assert_job_deserializes_under_force_rls(job)
      deserialized_job = ActiveJob::Base.deserialize(job.serialize)

      RowLevelSecurityTest.ensure_non_superuser_role
      ActiveRecord::Base.connection.execute("SET ROLE app_user")

      assert_nothing_raised do
        deserialized_job.send(:deserialize_arguments_if_needed)
      end
    ensure
      ActiveRecord::Base.connection.execute("RESET ROLE") rescue nil
    end
end
