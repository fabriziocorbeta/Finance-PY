class ChatsController < ApplicationController
  include ActionView::RecordIdentifier

  before_action :set_chat, only: [ :show, :edit, :update, :destroy ]

  def index
    @chat = nil # override application_controller default behavior of setting @chat to last viewed chat
    @chats = Current.user.chats.order(created_at: :desc)
  end

  def show
    set_last_viewed_chat(@chat)
  end

  def new
    @chat = Current.user.chats.new(title: "New chat #{Time.current.strftime("%Y-%m-%d %H:%M")}")
  end

  def create
    @chat = Current.user.chats.start!(chat_params[:content], model: chat_params[:ai_model])
    set_last_viewed_chat(@chat)
    redirect_to chat_path(@chat, thinking: true)
  rescue ActiveRecord::RecordInvalid => e
    # Model allowlist / quota / length violations on the first message land
    # here as a nested-association validation failure (Chat.start! creates
    # the chat and its first UserMessage together) -- always a friendly
    # redirect, never a 500.
    #
    # E5 corrector round 1 fix: e.record is the Chat, not the nested
    # UserMessage. When the UserMessage fails validation, autosave attaches
    # a generic "Messages is invalid" error to the Chat's own errors instead
    # of surfacing the child's specific message (e.g. "The requested AI
    # model is not allowed."), so reading e.record.errors alone always showed
    # that generic text. The failed UserMessage is still held in
    # e.record.messages (built, never persisted) with its own errors
    # populated -- read those first and fall back to the chat's own errors.
    chat = e.record
    message_errors = chat.messages.flat_map { |m| m.errors.full_messages }
    redirect_to new_chat_path, alert: message_errors.presence&.to_sentence || chat.errors.full_messages.to_sentence
  end

  def edit
  end

  def update
    @chat.update!(chat_params)

    respond_to do |format|
      format.html { redirect_back_or_to chat_path(@chat), notice: "Chat updated" }
      format.turbo_stream { render turbo_stream: turbo_stream.replace(dom_id(@chat, :title), partial: "chats/chat_title", locals: { chat: @chat }) }
    end
  end

  def destroy
    @chat.destroy
    clear_last_viewed_chat

    redirect_to chats_path, notice: "Chat was successfully deleted"
  end

  def retry
    # Same gap as Api::V1::MessagesController#retry (E5 corrector round 1):
    # retry_last_message! re-asks the assistant off the existing last
    # UserMessage instead of creating a new one, so UserMessage#llm_quota_available
    # never runs for it either. Not in the confirmed findings list (which only
    # named the API endpoint), but it's the same bypass on the web path, so
    # fixed alongside it rather than left open.
    family = @chat.user.family
    if UsageQuota.llm_quota_exceeded?(family)
      redirect_to chat_path(@chat), alert: I18n.t("chats.errors.llm_quota_exceeded")
      return
    end

    @chat.retry_last_message!
    redirect_to chat_path(@chat)
  end

  private
    def set_chat
      @chat = Current.user.chats.find(params[:id])
    end

    def set_last_viewed_chat(chat)
      Current.user.update!(last_viewed_chat: chat)
    end

    def clear_last_viewed_chat
      Current.user.update!(last_viewed_chat: nil)
    end

    def chat_params
      params.require(:chat).permit(:title, :content, :ai_model)
    end
end
