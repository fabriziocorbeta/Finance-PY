# frozen_string_literal: true

class Api::V1::MessagesController < Api::V1::BaseController
  before_action :require_ai_enabled
  before_action :ensure_write_scope, only: [ :create, :retry ]
  before_action :set_chat

  def create
    @message = @chat.messages.build(
      content: message_params[:content],
      type: "UserMessage",
      ai_model: message_params[:model].presence || Chat.default_model
    )

    if @message.save
      # NOTE: Commenting out duplicate job enqueue to fix mobile app receiving duplicate AI responses
      # UserMessage model already triggers AssistantResponseJob via after_create_commit callback
      # in app/models/user_message.rb:10-12, so this manual enqueue causes the job to run twice,
      # resulting in duplicate AI responses with different content and wasted tokens.
      # See: https://github.com/dwvwdv/sure (mobile app integration issue)
      # AssistantResponseJob.perform_later(@message)
      render :show, status: :created
    else
      render json: { error: "Failed to create message", details: @message.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def retry
    # E5 fix: retry triggers a real LLM call (AssistantResponseJob) same as
    # a normal message create, but was never covered by the family's daily
    # LLM token quota (that check lives on UserMessage#llm_quota_available,
    # and retry never creates a UserMessage). Check it explicitly here so a
    # caller can't loop this endpoint to bypass the quota entirely.
    if UsageQuota.llm_quota_exceeded?(@chat.user.family)
      render json: { error: I18n.t("chats.errors.llm_quota_exceeded") }, status: :unprocessable_entity
      return
    end

    # Same domain path as the web retry (ChatsController#retry): clears
    # chat.error and re-asks the assistant for the last user message -- the
    # failed-turn case, where Assistant::Builtin already destroyed the empty
    # reply -- and is idempotent for a double-tapped retry.
    if (assistant_message = @chat.retry_last_message!)
      render json: { message: "Retry initiated", message_id: assistant_message.id }, status: :accepted
    else
      render json: { error: "No assistant message to retry" }, status: :unprocessable_entity
    end
  end

  private

    def ensure_write_scope
      authorize_scope!(:write)
    end

    def set_chat
      @chat = Current.user.chats.find(params[:chat_id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: "Chat not found" }, status: :not_found
    end

    def message_params
      params.permit(:content, :model)
    end
end
