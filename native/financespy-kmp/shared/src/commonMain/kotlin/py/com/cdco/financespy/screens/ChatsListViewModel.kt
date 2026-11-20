package py.com.cdco.financespy.screens

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.api.dto.ChatDto
import py.com.cdco.financespy.sync.OfflineCache
import py.com.cdco.financespy.sync.OfflineCacheKeys
import py.com.cdco.financespy.sync.OfflineStore

data class ChatsListUiState(
    val chats: List<ChatDto> = emptyList(),
    val isLoading: Boolean = false,
    val error: String? = null
)

class ChatsListViewModel(
    private val scope: CoroutineScope,
    private val api: FinancePyApi,
    store: OfflineStore? = null
) {
    private val cache = OfflineCache(store)
    private val _state = MutableStateFlow(
        ChatsListUiState(
            chats = cache.getList(OfflineCacheKeys.CHATS_LIST, ChatDto.serializer()) ?: emptyList()
        )
    )
    val state: StateFlow<ChatsListUiState> = _state.asStateFlow()

    init {
        refresh()
    }

    fun refresh() {
        scope.launch {
            _state.value = _state.value.copy(isLoading = true, error = null)
            try {
                val response = api.fetchChats(page = 1)
                cache.putList(OfflineCacheKeys.CHATS_LIST, ChatDto.serializer(), response.chats)
                _state.value = _state.value.copy(chats = response.chats, isLoading = false)
            } catch (e: Exception) {
                _state.value = _state.value.copy(
                    isLoading = false,
                    error = if (_state.value.chats.isEmpty()) (e.message ?: "Error al cargar chats") else null
                )
            }
        }
    }
}
