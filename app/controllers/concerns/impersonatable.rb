module Impersonatable
  extend ActiveSupport::Concern

  included do
    after_action :end_expired_impersonation_session
    after_action :create_impersonation_session_log
  end

  private
    # Access stops at request time (Current.impersonated_user ignores an expired
    # session); this just tidies the records so it is reported as complete.
    def end_expired_impersonation_session
      ims = Current.session&.active_impersonator_session
      return unless ims&.expired?

      ims.complete!
      Current.session.update!(active_impersonator_session: nil)
    end

    def create_impersonation_session_log
      return unless Current.session&.active_impersonator_session&.active?

      Current.session.active_impersonator_session.logs.create!(
        controller: controller_name,
        action: action_name,
        path: request.fullpath,
        method: request.method,
        ip_address: request.ip,
        user_agent: request.user_agent
      )
    end
end
