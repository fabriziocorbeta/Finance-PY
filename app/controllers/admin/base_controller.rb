# frozen_string_literal: true

module Admin
  class BaseController < ApplicationController
    before_action :require_super_admin!

    # users/sessions/chats/messages/families-related tables are FORCE RLS
    # (see config/rls_inventory.yml), scoped to app.current_family_id -- the
    # admin's own family. Every Admin:: controller queries across ALL
    # families (user lists, family lists, usage metrics), so without this
    # bypass every admin screen silently showed only the signed-in admin's
    # own family's data. require_super_admin! runs first (before_action,
    # declared above) and can redirect-and-halt the chain, so this bypass
    # only ever activates for a verified super_admin.
    around_action :wrap_in_rls_auth_bypass

    layout "settings"

    private
      def require_super_admin!
        unless Current.user&.super_admin?
          redirect_to root_path, alert: t("admin.unauthorized") and return
        end
      end

      def wrap_in_rls_auth_bypass
        RlsContext.with_auth_bypass(reason: "admin_#{controller_name}##{action_name}") { yield }
      end
  end
end
