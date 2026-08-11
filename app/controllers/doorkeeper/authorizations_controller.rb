# frozen_string_literal: true

# Overrides Doorkeeper::AuthorizationsController#redirect_or_render only to
# special-case custom-scheme redirect_uris (e.g. financespy://oauth/callback,
# used by the mobile app's OAuth PKCE flow). Everything else is identical to
# the gem default (doorkeeper-5.8.2's app/controllers/doorkeeper/authorizations_controller.rb).
#
# Why: some Custom Tabs providers (confirmed live: Samsung Internet and Chrome,
# both on Android) silently ignore a raw HTTP 302 whose Location header points
# at a non-http(s) scheme -- the server logs correctly show a 302 to
# "financespy://oauth/callback?code=...&state=..." with the right code every
# time, but the browser never navigates there, so the app's authorize()
# promise (react-native-app-auth) never resolves and the login hangs on the
# browser screen indefinitely. This is a known integration gap between
# Doorkeeper's default raw redirect and mobile OAuth clients using custom
# URI schemes with Custom Tabs. The fix: for non-http(s) redirect_uris only,
# render an interstitial page that navigates there via JS/meta-refresh
# instead of a raw Location header -- script-triggered navigation to a
# custom scheme is honored by browsers that ignore the same URI in a raw
# redirect header. The redirect_uri (and its full query string: code, state,
# etc.) is otherwise completely unchanged, so this does not alter what
# react-native-app-auth's RedirectUriReceiverActivity receives.
module Doorkeeper
  class AuthorizationsController < Doorkeeper::ApplicationController
    before_action :authenticate_resource_owner!
    before_action :set_no_store_headers

    def new
      if pre_auth.authorizable?
        render_success
      else
        render_error
      end
    end

    def create
      redirect_or_render(authorize_response)
    end

    def destroy
      redirect_or_render(authorization.deny)
    rescue Doorkeeper::Errors::InvalidTokenStrategy => e
      error_response = get_error_response_from_exception(e)

      if Doorkeeper.configuration.api_only
        render json: error_response.body, status: :bad_request
      else
        render :error, locals: { error_response: error_response }
      end
    end

    private

      # This page is personalized (CSRF token, resource owner session) and its
      # POST issues a one-time authorization code, so it must never be cached.
      # Found live: Cloudflare was caching the GET response regardless of
      # query string, serving a stale copy of this page (old branding, old
      # button markup) to every login attempt, unrelated to whatever the
      # origin actually deployed. Standard Cache-Control should stop Cloudflare
      # from caching it at all; belt-and-suspenders since a dashboard-level
      # "Cache Everything" rule can still override origin headers.
      def set_no_store_headers
        response.headers["Cache-Control"] = "no-store, no-cache, private"
        response.headers["Pragma"] = "no-cache"
      end

      def render_success
        if skip_authorization? || can_authorize_response?
          redirect_or_render(authorize_response)
        elsif Doorkeeper.configuration.api_only
          render json: pre_auth
        else
          render :new
        end
      end

      def render_error
        pre_auth.error_response.raise_exception! if Doorkeeper.config.raise_on_errors?

        if Doorkeeper.configuration.redirect_on_errors? && pre_auth.error_response.redirectable?
          redirect_or_render(pre_auth.error_response)
        elsif Doorkeeper.configuration.api_only
          render json: pre_auth.error_response.body, status: pre_auth.error_response.status
        else
          render :error, locals: { error_response: pre_auth.error_response }, status: pre_auth.error_response.status
        end
      end

      def can_authorize_response?
        Doorkeeper.config.custom_access_token_attributes.empty? && pre_auth.client.application.confidential? && matching_token?
      end

      def matching_token?
        @matching_token ||= Doorkeeper.config.access_token_model.matching_token_for(
          pre_auth.client,
          current_resource_owner,
          pre_auth.scopes,
        )
      end

      def redirect_or_render(auth)
        if auth.redirectable?
          if Doorkeeper.configuration.api_only
            if pre_auth.form_post_response?
              render(
                json: { status: :post, redirect_uri: pre_auth.redirect_uri, body: auth.body },
                status: auth.status,
              )
            else
              render(
                json: { status: :redirect, redirect_uri: auth.redirect_uri },
                status: auth.status,
              )
            end
          elsif pre_auth.form_post_response?
            render :form_post, locals: { auth: auth }
          elsif custom_scheme_redirect?(auth.redirect_uri)
            render :native_redirect, locals: { redirect_uri: auth.redirect_uri }
          else
            redirect_to auth.redirect_uri, allow_other_host: true
          end
        else
          render json: auth.body, status: auth.status
        end
      end

      # True for any redirect_uri that isn't http(s) -- i.e. a native app's
      # custom URI scheme (financespy://, not the web app's own https:// URLs).
      def custom_scheme_redirect?(redirect_uri)
        uri = URI.parse(redirect_uri)
        uri.scheme.present? && !%w[http https].include?(uri.scheme)
      rescue URI::InvalidURIError
        false
      end

      def pre_auth
        @pre_auth ||= OAuth::PreAuthorization.new(
          Doorkeeper.configuration,
          pre_auth_params,
          current_resource_owner,
        )
      end

      def pre_auth_params
        params.slice(*pre_auth_param_fields).permit(*pre_auth_param_fields)
      end

      def pre_auth_param_fields
        custom_access_token_attributes + %i[
          client_id
          code_challenge
          code_challenge_method
          response_type
          response_mode
          redirect_uri
          scope
          state
        ]
      end

      def custom_access_token_attributes
        Doorkeeper.config.custom_access_token_attributes.map(&:to_sym)
      end

      def authorization
        @authorization ||= strategy.request
      end

      def strategy
        @strategy ||= server.authorization_request(pre_auth.response_type)
      end

      def authorize_response
        @authorize_response ||= begin
          return pre_auth.error_response unless pre_auth.authorizable?

          context = build_context(pre_auth: pre_auth)
          before_successful_authorization(context)

          auth = strategy.authorize

          context = build_context(auth: auth)
          after_successful_authorization(context)

          auth
        end
      end

      def build_context(**attributes)
        Doorkeeper::OAuth::Hooks::Context.new(**attributes)
      end

      def before_successful_authorization(context = nil)
        Doorkeeper.config.before_successful_authorization.call(self, context)
      end

      def after_successful_authorization(context)
        Doorkeeper.config.after_successful_authorization.call(self, context)
      end
  end
end
