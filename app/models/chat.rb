class Chat < ApplicationRecord
  include Encryptable

  # User-entered free text: encrypted at rest (owner/DB-leak protection). Not queried in SQL.
  if encryption_ready?
    encrypts :instructions
  end

  include Debuggable

  RATE_LIMIT_PATTERNS = [
    /\b429\b/i,
    /rate limit/i,
    /too many requests/i,
    /quota exceeded/i
  ].freeze

  TEMPORARY_PROVIDER_PATTERNS = [
    /\b5\d\d\b/i,
    /service unavailable/i,
    /temporarily unavailable/i,
    /gateway timeout/i,
    /bad gateway/i,
    /overloaded/i,
    /time(?:out|d?\s*out)/i,
    /connection reset/i
  ].freeze

  AUTH_CONFIGURATION_PATTERNS = [
    /unauthorized/i,
    /authentication/i,
    /invalid api key/i,
    /incorrect api key/i,
    /access token/i
  ].freeze

  belongs_to :user

  has_one :viewer, class_name: "User", foreign_key: :last_viewed_chat_id, dependent: :nullify # "Last chat user has viewed"
  has_many :messages, dependent: :destroy

  validates :title, presence: true

  scope :ordered, -> { order(created_at: :desc) }

  class << self
    def start!(prompt, model:)
      # Ensure we have a valid model by using the default if none provided
      effective_model = model.presence || default_model

      create!(
        title: generate_title(prompt),
        messages: [ UserMessage.new(content: prompt, ai_model: effective_model) ]
      )
    end

    def generate_title(prompt)
      prompt.first(80)
    end

    # Returns the default AI model to use for chats
    # Priority: AI Config > Setting
    def default_model
      Provider::Openai.effective_model.presence || Setting.openai_model
    end

    # Allowlist for the `ai_model` a client is permitted to request (E5:
    # ai_model arrives as a plain param on chat/message creation -- web
    # hidden field or raw JSON body on the API -- so it's client-controlled
    # and must be validated, not trusted; see UserMessage#ai_model_allowed).
    #
    # A literal hardcoded list of model names doesn't work here: self-hosted
    # deployments point OPENAI_MODEL/Setting.openai_model at an arbitrary
    # OpenAI-compatible model (see Provider::Openai::BANK_STATEMENT_MODEL,
    # e.g. "openai/gpt-oss-20b" for a custom gateway), so the *configured*
    # model must always be allowed. On top of that we allow our first-party
    # OpenAI model families via the prefixes the provider itself already
    # uses to decide whether it supports a model
    # (Provider::Openai::SUPPORTED_MODELS / #supports_model?), so this list
    # never drifts out of sync with what the provider will actually accept.
    def model_allowed?(model)
      return false if model.blank?
      return true if model == default_model

      Provider::Openai::SUPPORTED_MODELS.any? { |prefix| model.start_with?(prefix) }
    end
  end

  def needs_assistant_response?
    conversation_messages.ordered.last.role != "assistant"
  end

  # A pending AssistantMessage older than this is treated as orphaned (its job
  # died without reaching Assistant::Builtin's rescue, e.g. a worker killed
  # mid-deploy) rather than as a response still in flight, so a retry can
  # replace it instead of leaving the chat stuck on "thinking" forever.
  STALE_PENDING_RESPONSE_AFTER = 5.minutes

  # Re-asks the assistant to answer the most recent UserMessage. Covers both a
  # failed turn (Assistant::Builtin destroyed the empty reply, so the user
  # message is last, or demoted a partial reply to `failed`) and regenerating
  # an answer that did complete.
  #
  # Returns the pending AssistantMessage that will hold the answer, or nil when
  # the chat has no user message to answer. When a fresh pending reply already
  # exists for that user message (a response is in flight, or a double-tapped
  # retry), that one is returned and nothing new is enqueued.
  def retry_last_message!
    user_message = nil
    pending = nil
    stale = nil
    enqueue = false

    # Row lock on the chat serializes concurrent retries: the second request
    # waits here, then sees the first one's committed pending reply. It also
    # doubles as an RLS visibility check -- if the policy hid this chat from
    # the current context, the locking reload raises RecordNotFound instead of
    # the error-clearing UPDATE below silently matching zero rows.
    with_lock do
      update!(error: nil)

      user_message = messages.where(type: "UserMessage").ordered.last
      next unless user_message

      pending = messages.where(type: "AssistantMessage", status: "pending")
                        .where(created_at: user_message.created_at..)
                        .ordered.last

      if pending && pending.created_at < STALE_PENDING_RESPONSE_AFTER.ago
        stale = pending.destroy!
        pending = nil
      end

      unless pending
        pending = messages.create!(type: "AssistantMessage", content: "", ai_model: user_message.ai_model, status: :pending)
        enqueue = true
      end
    end

    broadcast_remove target: error_target
    stale&.broadcast_remove_to(self)
    # Enqueued only after the lock's transaction commits, so the worker can
    # never deserialize the job before the pending message row is visible.
    AssistantResponseJob.perform_later(user_message, pending) if enqueue
    pending
  end

  def update_latest_response!(provider_response_id)
    update!(latest_assistant_response_id: provider_response_id)
  end

  def add_error(e)
    update!(error: build_error_payload(e).to_json)
    broadcast_append target: messages_target, partial: "chats/error", locals: { chat: self }
  end

  def presentable_error_message
    return nil if error.blank?
    parsed_error_payload["message"].presence || classify_error_message(error)
  end

  def technical_error_message
    parsed_error_payload["technical_message"].presence || parsed_legacy_error_message || error
  end

  def clear_error
    update! error: nil
    broadcast_remove target: error_target
  end

  def conversation_messages
    messages.where(type: [ "UserMessage", "AssistantMessage" ])
  end

  def messages_target
    ActionView::RecordIdentifier.dom_id(self, :messages)
  end

  def error_target
    ActionView::RecordIdentifier.dom_id(self, :chat_error)
  end

  def ask_assistant_later(message)
    clear_error
    pending = messages.create!(type: "AssistantMessage", content: "", ai_model: message.ai_model, status: :pending)
    AssistantResponseJob.perform_later(message, pending)
  end

  def ask_assistant(message, assistant_message: nil)
    assistant.respond_to(message, assistant_message: assistant_message)
  end

  private

    def build_error_payload(error)
      technical_message = error_message_for(error)

      {
        message: classify_error_message(technical_message),
        technical_message: technical_message,
        type: error.class.name
      }
    end

    def classify_error_message(message)
      normalized_message = message.to_s.strip
      return I18n.t("chat.errors.default") if normalized_message.blank?

      if RATE_LIMIT_PATTERNS.any? { |pattern| normalized_message.match?(pattern) }
        I18n.t("chat.errors.rate_limited")
      elsif TEMPORARY_PROVIDER_PATTERNS.any? { |pattern| normalized_message.match?(pattern) }
        I18n.t("chat.errors.temporarily_unavailable")
      elsif AUTH_CONFIGURATION_PATTERNS.any? { |pattern| normalized_message.match?(pattern) }
        I18n.t("chat.errors.misconfigured")
      else
        I18n.t("chat.errors.default")
      end
    end

    def parsed_error_payload
      return {} if error.blank?
      return error if error.is_a?(Hash)

      parsed = JSON.parse(error)
      parsed.is_a?(Hash) ? parsed : {}
    rescue JSON::ParserError, TypeError
      {}
    end

    def error_message_for(error)
      error.respond_to?(:message) ? error.message.to_s : error.to_s
    rescue StandardError
      ""
    end

    def parsed_legacy_error_message
      parsed = JSON.parse(error)
      parsed.is_a?(String) ? parsed : nil
    rescue JSON::ParserError, TypeError
      nil
    end

    def assistant
      @assistant ||= Assistant.for_chat(self)
    end
end
