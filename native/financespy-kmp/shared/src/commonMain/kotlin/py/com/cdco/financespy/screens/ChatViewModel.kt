package py.com.cdco.financespy.screens

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.api.dto.MessageDto
import py.com.cdco.financespy.api.dto.ChatDto

data class ChatUiState(
    val title: String = "",
    val messages: List<MessageDto> = emptyList(),
    val isLoading: Boolean = false,
    val isSending: Boolean = false,
    val error: String? = null,
    val isNewChat: Boolean = false
)

class ChatViewModel(
    private val scope: CoroutineScope,
    private val api: FinancePyApi,
    val chatId: String?
) {
    // `scope` is MainActivity's Activity-lifetime lifecycleScope, shared by
    // every ChatViewModel instance (a new one is created per chat screen
    // visit via `remember(chatId) { ... }`, but none of them own a scope
    // tied to that screen). Launching directly on it meant the 2s/90-try
    // assistant-response poll from an old instance kept running for up to
    // 3 minutes after navigating to a different chat -- nothing ever
    // cancelled it. This child job is cancelled by `dispose()`, called from
    // the composable's DisposableEffect when the screen leaves or chatId
    // changes, without needing MainActivity's lifecycleScope to be touched.
    private val vmJob = SupervisorJob(scope.coroutineContext[Job])
    private val vmScope = CoroutineScope(scope.coroutineContext + vmJob)

    private val _state = MutableStateFlow(ChatUiState(isNewChat = chatId == "new" || chatId == null))
    val state: StateFlow<ChatUiState> = _state.asStateFlow()

    private var actualChatId: String? = if (chatId == "new") null else chatId
    private var isPolling = false

    fun dispose() {
        vmJob.cancel()
    }

    init {
        if (actualChatId != null) {
            refresh()
        }
    }

    fun refresh() {
        val id = actualChatId ?: return
        vmScope.launch {
            _state.value = _state.value.copy(isLoading = true, error = null)
            try {
                val response = api.fetchChat(id, page = 1)
                // Server returns oldest-first (`ordered` scope); ChatScreen's
                // LazyColumn is a plain (non-reversed) list that auto-scrolls to
                // the LAST index on new messages, so oldest-first is what it
                // needs. Reversing here (as this used to) put the newest message
                // at index 0 -- rendered at the TOP, away from the input, and
                // the auto-scroll (aimed at the last index) landed on the
                // oldest message instead. Confirmed live on device.
                _state.value = _state.value.copy(
                    title = response.title ?: "",
                    messages = response.messages ?: emptyList(),
                    isLoading = false
                )
                checkAndPoll(response.messages)
            } catch (e: Exception) {
                _state.value = _state.value.copy(isLoading = false, error = e.message ?: "Error al cargar chat")
            }
        }
    }

    fun sendMessage(content: String, model: String? = null) {
        if (content.isBlank()) return

        vmScope.launch {
            _state.value = _state.value.copy(isSending = true, error = null)
            try {
                if (actualChatId == null) {
                    // Create new chat
                    val response = api.createChat(title = null, message = content, model = model)
                    actualChatId = response.id
                    _state.value = _state.value.copy(
                        title = response.title ?: "",
                        messages = response.messages ?: emptyList(),
                        isSending = false,
                        isNewChat = false
                    )
                    checkAndPoll(response.messages)
                } else {
                    // Send message to existing chat. `_state.value.messages` is
                    // oldest-first, and the new message is the newest, so it goes
                    // at the END -- that's also the index ChatScreen's
                    // auto-scroll targets. hasPendingReply reads the list's last
                    // element, which this append keeps correct, so checkAndPoll
                    // works unchanged.
                    val response = api.sendMessage(actualChatId!!, content, model)
                    val updatedMessages = _state.value.messages + response
                    _state.value = _state.value.copy(
                        messages = updatedMessages,
                        isSending = false
                    )
                    checkAndPoll(updatedMessages)
                }
            } catch (e: Exception) {
                _state.value = _state.value.copy(isSending = false, error = e.message ?: "Error al enviar mensaje")
            }
        }
    }

    fun retryMessage() {
        val id = actualChatId ?: return
        vmScope.launch {
            _state.value = _state.value.copy(isSending = true, error = null)
            try {
                val response = api.retryMessage(id)
                val updatedMessages = _state.value.messages + response
                _state.value = _state.value.copy(
                    messages = updatedMessages,
                    isSending = false
                )
                checkAndPoll(updatedMessages)
            } catch (e: Exception) {
                 _state.value = _state.value.copy(isSending = false, error = e.message ?: "Error al reintentar mensaje")
            }
        }
    }

    private fun checkAndPoll(messages: List<MessageDto>?) {
        if (messages.isNullOrEmpty()) return

        if (hasPendingReply(messages)) {
            startPolling()
        }
    }

    private fun startPolling() {
        if (!isPolling) {
            isPolling = true
            vmScope.launch {
                pollForAssistantResponse()
            }
        }
    }

    private suspend fun pollForAssistantResponse() {
        val id = actualChatId ?: return
        var attempts = 0

        while (attempts < 90) { // Max 3 minutes polling (2s * 90)
            delay(2000)
            try {
                val response = api.fetchChat(id, page = 1)
                val messages = response.messages ?: emptyList()

                _state.value = _state.value.copy(
                    title = response.title ?: "",
                    messages = messages
                )

                // If there's an assistant message for the last user message, or no more pending, stop
                if (!hasPendingReply(messages)) {
                    break
                }

            } catch (e: Exception) {
                // Keep trying on intermittent failures
            }
            attempts++
            if (attempts >= 90) {
                 _state.value = _state.value.copy(
                     error = "La IA todavía está procesando. Por favor, revisá más tarde."
                 )
            }
        }
        isPolling = false
    }

    // The server never serializes ai_response_status/ai_response_message
    // (show.json.jbuilder has no such fields -- confirmed by reading it;
    // those MessageDto fields are dead on the wire). checkAndPoll relying on
    // `it.ai_response_status == "pending"` meant hasPending was always
    // false, so polling never started after sending a message: the chat
    // screen was stuck showing the user's message with a permanent "typing"
    // indicator, even once the assistant had actually replied -- only
    // leaving and reopening the chat (a fresh fetchChat, independent of
    // polling) ever showed the reply. Confirmed live on a real device.
    // Messages come back ordered oldest-first (server's `ordered` scope),
    // so whether a reply is still pending can be inferred directly: no
    // reply has arrived yet exactly when the last message is still a user
    // message.
    private fun hasPendingReply(messages: List<MessageDto>): Boolean {
        return messages.lastOrNull()?.type == "user_message"
    }
}
