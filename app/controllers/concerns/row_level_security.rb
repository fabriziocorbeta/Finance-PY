module RowLevelSecurity
  extend ActiveSupport::Concern

  included do
    around_action :set_postgres_rls_context
  end

  private

    def set_postgres_rls_context
      family_id = Current.family&.id

      if family_id.present?
        ActiveRecord::Base.connection.execute(
          ActiveRecord::Base.sanitize_sql(["SET app.current_family_id = ?", family_id])
        )
      else
        ActiveRecord::Base.connection.execute("RESET app.current_family_id") rescue nil
      end

      yield
    ensure
      ActiveRecord::Base.connection.execute("RESET app.current_family_id") rescue nil
    end
end
