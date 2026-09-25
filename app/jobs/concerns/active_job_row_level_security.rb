# frozen_string_literal: true

module ActiveJobRowLevelSecurity
  extend ActiveSupport::Concern

  included do
    around_perform :set_postgres_rls_context_for_job
  end

  private

    def set_postgres_rls_context_for_job
      family = resolve_job_family

      if family.present?
        RlsContext.with_family(family) do
          yield
        end
      else
        # No family could be resolved from this job's arguments. Do NOT just
        # yield: the connection this job's thread checks out could in theory
        # still carry a stale app.current_family_id from a prior job/request
        # if the connection-pool safety net (config/initializers/
        # rls_connection_safety.rb) didn't run yet for this connection, or a
        # future code path bypasses it. Explicitly reset before running, so a
        # family-less job never silently inherits someone else's RLS scope.
        RlsContext.reset
        yield
      end
    end

    def resolve_job_family
      arguments.each do |arg|
        family = extract_family(arg)
        return family if family.present?
      end

      nil
    end

    def extract_family(arg)
      if arg.is_a?(Family)
        arg
      elsif arg.respond_to?(:family) && arg.family.is_a?(Family)
        arg.family
      elsif arg.respond_to?(:family_id) && arg.family_id.present?
        Family.find_by(id: arg.family_id)
      elsif arg.respond_to?(:chat) && arg.chat.respond_to?(:family) && arg.chat.family.is_a?(Family)
        arg.chat.family
      elsif arg.is_a?(Hash)
        extract_family_from_hash(arg)
      elsif arg.is_a?(String) || arg.is_a?(Integer)
        extract_family_from_id(arg)
      end
    end

    def extract_family_from_hash(hash)
      hash = hash.with_indifferent_access
      if hash[:family].is_a?(Family)
        hash[:family]
      elsif hash[:family_id].present?
        Family.find_by(id: hash[:family_id])
      elsif hash[:simplefin_item_id].present?
        SimplefinItem.find_by(id: hash[:simplefin_item_id])&.family
      elsif hash[:snaptrade_item_id].present?
        SnaptradeItem.find_by(id: hash[:snaptrade_item_id])&.family
      elsif hash[:indexa_capital_item_id].present?
        IndexaCapitalItem.find_by(id: hash[:indexa_capital_item_id])&.family
      elsif hash[:statement_import_id].present?
        StatementImport.find_by(id: hash[:statement_import_id])&.family
      elsif hash[:simplefin_account_id].present?
        SimplefinAccount.find_by(id: hash[:simplefin_account_id])&.simplefin_item&.family
      end
    end

    def extract_family_from_id(id)
      Family.find_by(id: id) ||
        StatementImport.find_by(id: id)&.family ||
        SimplefinAccount.find_by(id: id)&.simplefin_item&.family ||
        SimplefinItem.find_by(id: id)&.family ||
        SnaptradeItem.find_by(id: id)&.family ||
        IndexaCapitalItem.find_by(id: id)&.family
    end
end
