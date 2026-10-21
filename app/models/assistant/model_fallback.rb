# Keeps an assistant turn alive when the LLM provider is busy or slow: the
# requested model goes first, then each model in OPENAI_FALLBACK_MODELS.
#
# - A busy answer (HTTP 429/503) gets one more try on the same model after
#   BUSY_RETRY_DELAY seconds; other retryable failures (500/502/504, timeouts,
#   connection errors) move straight to the next model.
# - Every model except the last gets OPENAI_CHAT_ATTEMPT_TIMEOUT seconds
#   (default 25); the last one keeps the full OPENAI_REQUEST_TIMEOUT (default
#   60) because it is the last resort.
# - Anything else (400/401/403/404, tool errors, ...) is re-raised untouched.
#
# The timeout is the HTTP read timeout (ruby-openai `request_timeout`), i.e. the
# longest wait for the next bytes, not a cap on the whole request. That bounds
# the non-streaming chat-completions call used with OpenAI-compatible endpoints
# (nothing arrives until the answer is complete). On the streaming Responses
# API path it only bounds the gaps between events, so it does not cap how long
# a model may take to produce its first text there.
#
# Worst case with the defaults and a 3-model chain, every model busy and each
# 503 arriving just before the timeout: 2 x (25s + 2s + 25s) + (60s + 2s + 60s)
# ~ 3m46s, all spent inside AssistantResponseJob, never in a web request. With
# no fallback models: 60s + 2s + 60s ~ 2 minutes. Once tools have run the
# follow-up call gets the full OPENAI_REQUEST_TIMEOUT (no model can take over).
class Assistant::ModelFallback
  DEFAULT_ATTEMPT_TIMEOUT = 25
  BUSY_RETRY_DELAY = 2
  BUSY_RETRIES_PER_MODEL = 1

  # Every model in the chain failed with a retryable error.
  Exhausted = Class.new(Assistant::Error)

  attr_reader :models

  def initialize(primary_model)
    @models = [ primary_model, *fallback_models ].compact_blank.uniq
  end

  # Yields (model, request_timeout) until an attempt succeeds. request_timeout
  # is nil for the last model (use the provider default). `retry_allowed`
  # must return false once the turn has visible output, so a model that
  # already streamed text or ran tools is never answered over by another one.
  def run(retry_allowed:)
    models.each_with_index do |model, index|
      last_model = index == models.size - 1
      busy_retries_left = BUSY_RETRIES_PER_MODEL

      begin
        return yield(model, last_model ? nil : attempt_timeout)
      rescue => error
        raise unless retryable?(error) && retry_allowed.call

        if busy?(error) && busy_retries_left.positive?
          busy_retries_left -= 1
          Rails.logger.info("[Assistant] #{model} failed (#{failure_label(error)}); retrying it in #{BUSY_RETRY_DELAY}s")
          wait(BUSY_RETRY_DELAY)
          retry
        end

        if last_model
          Rails.logger.info("[Assistant] #{model} failed (#{failure_label(error)}); no models left (tried #{models.join(', ')})")
          raise Exhausted, "All assistant models were busy or too slow (tried #{models.join(', ')}); last failure: #{failure_label(error)}"
        end

        Rails.logger.info("[Assistant] #{model} failed (#{failure_label(error)}); falling back to #{models[index + 1]}")
      end
    end
  end

  private

    def fallback_models
      ENV["OPENAI_FALLBACK_MODELS"].to_s.split(",").map(&:strip)
    end

    # `.presence` because compose passes unset vars through as "" (${VAR:-}).
    def attempt_timeout
      seconds = ENV["OPENAI_CHAT_ATTEMPT_TIMEOUT"].presence&.to_i
      seconds&.positive? ? seconds : DEFAULT_ATTEMPT_TIMEOUT
    end

    def retryable?(error)
      error.respond_to?(:retryable?) && error.retryable?
    end

    def busy?(error)
      error.respond_to?(:busy?) && error.busy?
    end

    # Status/kind only: provider messages can echo request details.
    def failure_label(error)
      if error.respond_to?(:http_status) && error.http_status
        "HTTP #{error.http_status}"
      elsif error.respond_to?(:transport_failure) && error.transport_failure
        error.transport_failure.to_s
      else
        error.class.name
      end
    end

    def wait(seconds)
      sleep(seconds)
    end
end
