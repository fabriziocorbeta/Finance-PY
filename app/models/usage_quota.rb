# frozen_string_literal: true

# Per-family daily caps on the two costliest operations in the app: LLM token
# usage (chat responses, auto-categorization, bank-statement extraction via
# the AI provider) and PDF pages processed (PDF imports, receipts, bank
# statement imports). These exist to bound a single family's exposure -- a
# compromised account, a scripted client bypassing the UI, or a runaway retry
# loop -- to a fixed daily cost rather than an unbounded one.
#
# This is deliberately separate from Rack::Attack (config/initializers/rack_attack.rb):
# Rack::Attack limits request *rate* (bursts per minute/hour) before a
# request reaches a controller. UsageQuota limits total *resource
# consumption* over a rolling day, measured from what actually got
# processed/billed, so it still applies even if a client spreads requests out
# to stay under the rate limit.
class UsageQuota
  # Overridable per deployment via ENV. 0 (or unset default) enforces the
  # limit; set to a non-positive number to disable a specific cap -- useful
  # for self-hosted installs where the family isn't paying Anthropic/OpenAI
  # per token and the operator wants no cap.
  DAILY_LLM_TOKEN_LIMIT = ENV.fetch("LLM_DAILY_TOKEN_QUOTA_PER_FAMILY", "500000").to_i
  DAILY_PDF_PAGE_LIMIT  = ENV.fetch("PDF_DAILY_PAGE_QUOTA_PER_FAMILY", "500").to_i

  PDF_PAGES_CACHE_PREFIX = "usage_quota:pdf_pages"

  class << self
    # --- LLM tokens ---------------------------------------------------
    # Measured directly off the existing llm_usages table (LlmUsage) --
    # no separate counter to keep in sync. This only reflects usage
    # that *completed* (LlmUsage rows are written after a provider
    # call returns), so quota is deliberately measured just before
    # starting a new request, not "reserved" ahead of time.
    def llm_tokens_used_today(family)
      LlmUsage.for_family(family).where(created_at: Time.current.all_day).sum(:total_tokens)
    end

    def llm_quota_exceeded?(family)
      return false unless family
      return false if DAILY_LLM_TOKEN_LIMIT <= 0

      llm_tokens_used_today(family) >= DAILY_LLM_TOKEN_LIMIT
    end

    # --- PDF pages -------------------------------------------------------
    # llm_usages has no notion of "pages" (PDF extraction isn't always an
    # LLM call -- StatementParser::PdfExtractor uses PDF::Reader directly,
    # no tokens involved), so there's no existing table to measure this
    # from. Rather than add a persisted ledger (and its own cleanup job),
    # this uses a single Rails.cache counter per family per day: it's
    # Redis-backed and shared across processes in production/staging
    # (config/environments/production.rb), and a day-scoped TTL resets it
    # for free. In test/development it falls back to a null/memory store,
    # which is fine -- quota is disabled outside prod/staging the same way
    # Rack::Attack is (see rack_attack.rb), and tests swap in a real store
    # the same way test/integration/rack_attack_test.rb does.
    #
    # Known tradeoff: read-then-write is not atomic, so two PDFs finishing
    # in the same instant for the same family could both pass the check.
    # Acceptable for a soft daily cap; not used for anything security- or
    # money-critical (no financial data is modified based on this).
    def pdf_pages_used_today(family)
      return 0 unless family

      Rails.cache.read(pdf_pages_cache_key(family)).to_i
    end

    def pdf_quota_exceeded?(family, additional_pages: 0)
      return false unless family
      return false if DAILY_PDF_PAGE_LIMIT <= 0

      (pdf_pages_used_today(family) + additional_pages.to_i) > DAILY_PDF_PAGE_LIMIT
    end

    def record_pdf_pages!(family, count)
      return unless family
      return if count.to_i <= 0

      key = pdf_pages_cache_key(family)
      current = Rails.cache.read(key).to_i
      Rails.cache.write(key, current + count.to_i, expires_in: 26.hours)
    end

    private

      def pdf_pages_cache_key(family)
        "#{PDF_PAGES_CACHE_PREFIX}:#{family.id}:#{Time.current.strftime('%Y-%m-%d')}"
      end
  end
end
