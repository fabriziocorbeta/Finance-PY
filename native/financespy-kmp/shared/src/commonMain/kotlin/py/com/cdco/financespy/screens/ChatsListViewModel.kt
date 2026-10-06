package py.com.cdco.financespy.screens

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.api.dto.ChatDto

data class ChatsListUiState(
    val chats: List<ChatDto> = emptyList(),
    val isLoading: Boolean = false,
    val error: String? = null
)

class ChatsListViewModel(
    private val scope: CoroutineScope,
    private val api: FinancePyApi
) {
    private val _state = MutableStateFlow(ChatsListUiState())
    val state: StateFlow<ChatsListUiState> = _state.asStateFlow()

    init {
        refresh()
    }

    fun refresh() {
        scope.launch {
            _state.value = _state.value.copy(isLoading = true, error = null)
            try {
                // For simplicity we just fetch the first page.
                // Could expand with full pagination logic if desired.
                val response = api.fetchChats(page = 1)
                _state.value = _state.value.copy(chats = response.chats, isLoading = false)
            } catch (e: Exception) {
                _state.value = _state.value.copy(isLoading = false, error = e.message ?: "Error al cargar chats")
            }
        }
    }
}
