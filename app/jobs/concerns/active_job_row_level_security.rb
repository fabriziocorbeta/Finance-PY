module ActiveJobRowLevelSecurity
  extend ActiveSupport::Concern

  included do
    around_perform :set_postgres_rls_context_for_job
  end

  private

    def set_postgres_rls_context_for_job
      family = resolve_job_family

      if family.present?
        ActiveRecord::Base.connection.execute(
          ActiveRecord::Base.sanitize_sql(["SET app.current_family_id = ?", family.id])
        )
      end

      yield
    ensure
      ActiveRecord::Base.connection.execute("RESET app.current_family_id") rescue nil
    end

    def resolve_job_family
      arguments.each do |arg|
        if arg.is_a?(Family)
          return arg
        elsif arg.respond_to?(:family) && arg.family.is_a?(Family)
          return arg.family
        elsif arg.is_a?(Hash) && arg[:family_id].present?
          return Family.find_by(id: arg[:family_id])
        elsif arg.is_a?(Hash) && arg["family_id"].present?
          return Family.find_by(id: arg["family_id"])
        end
      end

      nil
    end
end
