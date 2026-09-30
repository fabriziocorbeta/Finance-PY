# frozen_string_literal: true

# Base controller for every Doorkeeper-mounted route (/oauth/authorize,
# /oauth/token, /oauth/revoke, /oauth/token/info, the admin applications
# UI). Wired in via `base_controller` in config/initializers/doorkeeper.rb.
#
# Deliberately not ApplicationController: Doorkeeper's own
# resource_owner_authenticator/admin_authenticator blocks in that same
# initializer already replicate our session-based auth manually (see their
# comments), specifically to avoid double-running our Authentication concern
# here. This class adds exactly one thing on top of plain ActionController::Base
# -- wrapping the whole action in RlsContext.with_auth_bypass.
#
# Why every action needs this: Doorkeeper's internal strategy classes
# (Doorkeeper::OAuth::AuthorizationCodeRequest, RefreshTokenRequest, etc.)
# read and write oauth_access_tokens/oauth_access_grants directly via
# ActiveRecord, entirely outside our RlsContext -- there is no single
# app.current_family_id to set for a token exchange anyway (it's scoped to
# one specific token/grant/client by exact id or hashed value, the same
# "auth" shape as sessions/api_keys/users, not a family-wide read). Without
# this, FORCE ROW LEVEL SECURITY on those two tables breaks every OAuth
# flow -- the mobile app's primary login path.
class DoorkeeperRlsController < ActionController::Base
  around_action :wrap_in_rls_auth_bypass

  private
    def wrap_in_rls_auth_bypass
      RlsContext.with_auth_bypass(reason: "doorkeeper_#{controller_name}##{action_name}") { yield }
    end
end
