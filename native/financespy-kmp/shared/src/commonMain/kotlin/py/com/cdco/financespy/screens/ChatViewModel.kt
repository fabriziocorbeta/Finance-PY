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
                _state.value = _state.value.copy(
                    title = response.title ?: "",
                    messages = response.messages?.reversed() ?: emptyList(), // Display newest at bottom
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
                        messages = response.messages?.reversed() ?: emptyList(),
                        isSending = false,
                        isNewChat = false
                    )
                    checkAndPoll(response.messages)
                } else {
                    // Send message to existing chat
                    val response = api.sendMessage(actualChatId!!, content, model)
                    val updatedMessages = _state.value.messages + response // Append to end
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

        // Find if there's any pending user message
        val hasPending = messages.any { it.type == "user_message" && it.ai_response_status == "pending" }

        if (hasPending && !isPolling) {
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
                    messages = messages.reversed()
                )

                // If there's an assistant message for the last user message, or no more pending, stop
                val hasPending = messages.any { it.type == "user_message" && it.ai_response_status == "pending" }
                if (!hasPending) {
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
}
