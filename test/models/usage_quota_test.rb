require "test_helper"

class UsageQuotaTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @previous_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    Rails.cache = @previous_cache
  end

  test "llm_tokens_used_today sums today's llm_usages for the family only" do
    LlmUsage.create!(family: @family, provider: "openai", model: "gpt-4.1", operation: "chat_response",
                      prompt_tokens: 100, completion_tokens: 50, total_tokens: 150)
    LlmUsage.create!(family: @family, provider: "openai", model: "gpt-4.1", operation: "chat_response",
                      prompt_tokens: 10, completion_tokens: 5, total_tokens: 15, created_at: 2.days.ago)
    other_family = families(:empty)
    LlmUsage.create!(family: other_family, provider: "openai", model: "gpt-4.1", operation: "chat_response",
                      prompt_tokens: 1_000, completion_tokens: 0, total_tokens: 1_000)

    assert_equal 150, UsageQuota.llm_tokens_used_today(@family)
  end

  test "llm_quota_exceeded? is true once today's usage reaches the daily limit" do
    LlmUsage.create!(family: @family, provider: "openai", model: "gpt-4.1", operation: "chat_response",
                      prompt_tokens: UsageQuota::DAILY_LLM_TOKEN_LIMIT, completion_tokens: 0,
                      total_tokens: UsageQuota::DAILY_LLM_TOKEN_LIMIT)

    assert UsageQuota.llm_quota_exceeded?(@family)
  end

  test "llm_quota_exceeded? is false with no usage" do
    assert_not UsageQuota.llm_quota_exceeded?(@family)
  end

  test "pdf pages accumulate per family per day and reset via a fresh cache" do
    assert_equal 0, UsageQuota.pdf_pages_used_today(@family)

    UsageQuota.record_pdf_pages!(@family, 3)
    UsageQuota.record_pdf_pages!(@family, 2)

    assert_equal 5, UsageQuota.pdf_pages_used_today(@family)
  end

  test "pdf_quota_exceeded? accounts for pages about to be added" do
    UsageQuota.record_pdf_pages!(@family, UsageQuota::DAILY_PDF_PAGE_LIMIT - 2)

    assert_not UsageQuota.pdf_quota_exceeded?(@family, additional_pages: 2)
    assert UsageQuota.pdf_quota_exceeded?(@family, additional_pages: 3)
  end
end
