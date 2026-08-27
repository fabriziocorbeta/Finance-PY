# frozen_string_literal: true

module RowLevelSecurity
  extend ActiveSupport::Concern

  included do
    around_action :set_postgres_rls_context
  end

  private

    def set_postgres_rls_context
      RlsContext.with_family(Current.family&.id) do
        yield
      end
    end
end
