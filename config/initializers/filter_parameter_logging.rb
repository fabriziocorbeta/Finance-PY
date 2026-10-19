# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :openai_access_token,
  :client_id, :consumer_key, :snaptrade_user_id, :snaptrade_user_secret,
  :amount, :name, :notes, :description, :balance, :client_name, :address, :phone, :ruc, :merchant
]

# HTTP HEADERS. `filter_parameters` above only covers request *params*; it does
# not touch headers. logtail-rails logs a structured `http_request_received` /
# `http_response_sent` event for every request, with all request and response
# headers serialized into `headers_json` -- and in production those events go
# to Better Stack whenever LOGTAIL_API_KEY is set (config/environments/
# production.rb), otherwise to STDOUT and from there into the Docker logs.
#
# `Logtail::Integrations::Rack::HTTPEvents.http_header_filters` has NO default:
# `filter_http_headers` does `http_header_filters&.include?(...)`, which is nil
# until something assigns it, so nothing was being filtered. The gem ships this
# exact initializer in its own example-project and expects you to set it; this
# app never did. The result was every session cookie, OAuth bearer token and
# API key travelling to an external log service in cleartext, where anyone with
# read access to the logs could replay them.
#
# Beyond the gem's example list (:authorization, :proxy_authorization, :cookie)
# this adds the two that matter for how this app authenticates: `X-Api-Key` for
# the v1 API, and `Set-Cookie` on the response, which carries the freshly
# minted session token on every login.
if defined?(Logtail::Integrations::Rack::HTTPEvents)
  Logtail::Integrations::Rack::HTTPEvents.http_header_filters = [
    :authorization,
    :proxy_authorization,
    :cookie,
    :set_cookie,
    :x_api_key,
    :x_csrf_token
  ]
end
