# frozen_string_literal: true

module RlsContext
  class << self
    def set_family(family_or_id)
      family_id = case family_or_id
                  when Family then family_or_id.id
                  when String, Integer then family_or_id
                  else family_or_id&.id if family_or_id.respond_to?(:id)
                  end

      if family_id.present?
        ActiveRecord::Base.connection.execute(
          ActiveRecord::Base.sanitize_sql(["SET app.current_family_id = ?", family_id])
        )
      else
        reset
      end
    end

    def reset
      ActiveRecord::Base.connection.execute("RESET app.current_family_id") rescue nil
    end

    def with_family(family_or_id)
      set_family(family_or_id)
      yield
    ensure
      reset
    end
  end
end
