# frozen_string_literal: true

# Base controller for Doorkeeper::ApplicationMetalController (TokensController:
# /oauth/token, /oauth/revoke, /oauth/introspect). Wired in via
# `base_metal_controller` in config/initializers/doorkeeper.rb.
#
# DoorkeeperRlsController (same directory) wraps the OTHER Doorkeeper
# controllers (AuthorizationsController, the admin ApplicationsController)
# via the separate `base_controller` option -- but TokensController does not
# inherit from that at all. Doorkeeper hardcodes
# `TokensController < Doorkeeper::ApplicationMetalController`, which resolves
# `base_metal_controller` (a *different* config key, defaulting to plain
# ActionController::API) instead. Setting only `base_controller` therefore
# leaves every /oauth/token request completely unwrapped: with
# oauth_access_grants/oauth_access_tokens under FORCE ROW LEVEL SECURITY and
# no bypass, Doorkeeper's own grant/token lookups inside TokensController#create
# see zero rows and fail with invalid_grant on every single exchange --
# authorization-code login AND refresh_token renewal both broken, 100% of
# the time, for every client. Found 2026-09-30: every brand-new login failed
# post-migration, and every already-logged-in session would have dropped
# within one access-token lifetime (2h) once its refresh attempt hit this
# same dead end.
class DoorkeeperRlsMetalController < ActionController::API
  around_action :wrap_in_rls_auth_bypass

  private
    def wrap_in_rls_auth_bypass
      RlsContext.with_auth_bypass(reason: "doorkeeper_metal_#{controller_name}##{action_name}") { yield }
    end
end
