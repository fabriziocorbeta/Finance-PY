# frozen_string_literal: true

class Api::V1::ChatsController < Api::V1::BaseController
  include Pagy::Backend
  before_action :require_ai_enabled
  before_action :ensure_read_scope, only: [ :index, :show ]
  before_action :ensure_write_scope, only: [ :create, :update, :destroy ]
  before_action :set_chat, only: [ :show, :update, :destroy ]

  def index
    @pagy, @chats = pagy(Current.user.chats.ordered, items: 20)
  end

  def show
    return unless @chat
    @pagy, @messages = pagy(@chat.messages.ordered, items: 50)
  end

  def create
    # The native mobile app's "new chat" flow deliberately sends no title --
    # same as web's own ChatsController#create (Chat.start!), it expects one
    # generated from the first message. This endpoint never did that: it
    # passed chat_params[:title] straight through, so a nil title always hit
    # `validates :title, presence: true` and every mobile "new chat" 422'd
    # with "Title no puede estar vacío" (confirmed live on a real device).
    # The only existing test for this action always supplied an explicit
    # title, so nothing caught it. Reuses Chat.generate_title (already used
    # by Chat.start!) instead of duplicating its truncation logic here.
    @chat = Current.user.chats.build(title: chat_params[:title].presence || generated_title)

    if @chat.save
      if chat_params[:message].present?
        @message = @chat.messages.build(
          content: chat_params[:message],
          type: "UserMessage",
          ai_model: chat_params[:model].presence || Chat.default_model
        )

        if @message.save
          # NOTE: Commenting out duplicate job enqueue to fix mobile app receiving duplicate AI responses
          # UserMessage model already triggers AssistantResponseJob via after_create_commit callback
          # in app/models/user_message.rb:10-12, so this manual enqueue causes the job to run twice,
          # resulting in duplicate AI responses with different content and wasted tokens.
          # See: https://github.com/dwvwdv/sure (mobile app integration issue)
          # AssistantResponseJob.perform_later(@message)
          #
          # show.json.jbuilder iterates @messages -- show sets it, but this
          # action never did, so every "new chat with first message" response
          # rendered "messages": [] even though @message had just saved fine.
          # Confirmed live: chat + title created correctly, message persisted,
          # but the native app's chat screen stayed empty after sending.
          @messages = @chat.messages.ordered
          render :show, status: :created
        else
          @chat.destroy
          render json: { error: "Failed to create initial message", details: @message.errors.full_messages }, status: :unprocessable_entity
        end
      else
        render :show, status: :created
      end
    else
      render json: { error: "Failed to create chat", details: @chat.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    return unless @chat

    if @chat.update(update_chat_params)
      render :show
    else
      render json: { error: "Failed to update chat", details: @chat.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    return unless @chat
    @chat.destroy
    head :no_content
  end

  private

    def ensure_read_scope
      authorize_scope!(:read)
    end

    def ensure_write_scope
      authorize_scope!(:write)
    end

    def set_chat
      @chat = Current.user.chats.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: "Chat not found" }, status: :not_found
    end

    def chat_params
      params.permit(:title, :message, :model)
    end

    # Falls back to "New chat" only if somehow neither a title nor a message
    # was sent -- keeps the pre-existing "blank title with no message"
    # failure mode (a validation error, not a crash) instead of introducing
    # a new one here.
    def generated_title
      return "New chat" unless chat_params[:message].present?

      Chat.generate_title(chat_params[:message])
    end

    def update_chat_params
      params.permit(:title)
    end
end
