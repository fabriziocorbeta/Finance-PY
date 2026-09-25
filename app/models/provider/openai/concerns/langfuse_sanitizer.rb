module Provider::Openai::Concerns::LangfuseSanitizer
  extend ActiveSupport::Concern

  private

    # Langfuse spans/traces/generations carry the actual LLM input (transactions,
    # notes, merchant names, amounts, PDF text) and output (categorization results,
    # extracted statement data) to a third party. In production we redact that
    # content by default -- callers still get span/trace/generation records
    # (useful for latency/error/usage debugging) but with content replaced by
    # shape-only placeholders, not the real financial data.
    #
    # Set LANGFUSE_ALLOW_FULL_CONTENT=true to opt back into full content capture
    # in production (e.g. for a temporary eval/debugging run against already-
    # consented data). Non-production environments keep full content by default
    # since eval/dataset tooling (app/models/eval/langfuse/*) relies on real
    # payloads there.
    def langfuse_redact_content?
      return false unless Rails.env.production?

      !ActiveModel::Type::Boolean.new.cast(ENV["LANGFUSE_ALLOW_FULL_CONTENT"])
    end

    def sanitize_for_langfuse(value)
      return value unless langfuse_redact_content?

      redact_for_langfuse(value)
    end

    def redact_for_langfuse(value)
      case value
      when Hash
        value.transform_values { |v| redact_for_langfuse(v) }
      when Array
        { redacted: true, count: value.size }
      when String
        { redacted: true, length: value.length }
      when Numeric, TrueClass, FalseClass, NilClass
        value
      else
        { redacted: true, type: value.class.name }
      end
    end
end
