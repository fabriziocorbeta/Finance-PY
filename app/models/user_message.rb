class UserMessage < Message
  has_one_attached :attachment, dependent: :purge_later

  MAX_ATTACHMENT_SIZE = 10.megabytes
  ALLOWED_ATTACHMENT_CONTENT_TYPES = %w[
    image/jpeg image/jpg image/png image/gif image/webp
    application/pdf
  ].freeze

  validates :ai_model, presence: true
  validates :content, length: { maximum: Message::MAX_CONTENT_LENGTH }, allow_blank: true

  # E5: ai_model and content both arrive as plain request params (web hidden
  # field or raw API/JSON body -- see MessagesController, Api::V1::MessagesController,
  # Api::V1::ChatsController, ChatsController), so both are client-controlled
  # input and must be validated before we act on them, not trusted.
  validate :ai_model_allowed, if: :ai_model?
  validate :llm_quota_available, on: :create
  validate :validate_attachment, if: -> { attachment.attached? }

  after_create_commit :request_response_later

  def role
    "user"
  end

  def prompt_for_llm
    base = content.to_s
    return base unless attachment.attached?

    note = "[Adjunto: #{attachment.filename} (message_id: #{id})]"
    base.present? ? "#{base}\n\n#{note}" : note
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

    def validate_attachment
      blob = attachment.blob
      return unless blob

      unless blob.content_type.in?(ALLOWED_ATTACHMENT_CONTENT_TYPES)
        errors.add(:attachment, "must be a JPEG, PNG, GIF, WebP image or PDF")
      end

      if blob.byte_size > MAX_ATTACHMENT_SIZE
        errors.add(:attachment, "must be less than 10MB")
      end
    end
end
