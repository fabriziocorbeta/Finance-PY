class Message < ApplicationRecord
  include Encryptable

  # User-entered free text: encrypted at rest (owner/DB-leak protection). Not queried in SQL.
  if encryption_ready?
    encrypts :content
  end

  belongs_to :chat
  has_many :tool_calls, dependent: :destroy

  enum :status, {
    pending: "pending",
    complete: "complete",
    failed: "failed"
  }

  # E5: bound on user-supplied message content (enforced in UserMessage,
  # below -- kept here so both the constant and its rationale live next to
  # the shared `content` column). 20,000 chars is roughly 4-5k tokens:
  # generously above any real chat turn (typical messages are a few
  # sentences; even a pasted error log or CSV snippet for context runs a
  # few KB), while still bounding the worst-case prompt size a single
  # request can force the LLM provider to process (cost) and the encrypted
  # row size stored per message.
  #
  # Not applied to AssistantMessage: #append_text! streams provider output
  # into `content` in chunks via incremental `save!` calls, so capping it
  # here could raise mid-stream on a long-but-legitimate response and leave
  # a partial message; the response length is already bounded upstream by
  # Setting.llm_max_response_tokens.
  MAX_CONTENT_LENGTH = 20_000

  validates :content, presence: true, unless: :pending?

  after_create_commit -> { broadcast_append_to chat, target: chat.messages_target }, if: :broadcast?
  after_update_commit -> { broadcast_update_to chat }, if: :broadcast?

  scope :ordered, -> { order(created_at: :asc) }

  private
    def broadcast?
      true
    end
end
