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
