class UserMessage < Message
  validates :ai_model, presence: true
  validates :content, length: { maximum: Message::MAX_CONTENT_LENGTH }, allow_blank: true

  # E5: ai_model and content both arrive as plain request params (web hidden
  # field or raw API/JSON body -- see MessagesController, Api::V1::MessagesController,
  # Api::V1::ChatsController, ChatsController), so both are client-controlled
  # input and must be validated before we act on them, not trusted.
  validate :ai_model_allowed, if: :ai_model?
  validate :llm_quota_available, on: :create

  after_create_commit :request_response_later

  def role
    "user"
  end

  def request_response_later
    chat.ask_assistant_later(self)
  end

  def request_response(assistant_message: nil)
    chat.ask_assistant(self, assistant_message: assistant_message)
  end

  private
    def ai_model_allowed
      return if Chat.model_allowed?(ai_model)

      errors.add(:base, I18n.t("chats.errors.invalid_model"))
    end

    # Checked at message-creation time (not just before dispatching to the
    # provider) so a family over quota gets an immediate, friendly error
    # instead of the message sitting `pending` until the background job
    # (AssistantResponseJob, enqueued by request_response_later above) picks
    # it up and fails there.
    def llm_quota_available
      family = chat&.user&.family
      return unless family
      return unless UsageQuota.llm_quota_exceeded?(family)

      errors.add(:base, I18n.t("chats.errors.llm_quota_exceeded"))
    end
end
