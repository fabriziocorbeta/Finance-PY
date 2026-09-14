package py.com.cdco.financespy.screens

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.navigation.NavItem
import py.com.cdco.financespy.navigation.NavItems
import py.com.cdco.financespy.navigation.NavPreferences

data class NavCustomizationUiState(
    val pool: List<NavItem> = emptyList(),
    val selectedIds: List<String> = emptyList(),
    val maxSelectable: Int = 6
)

// El orden de la barra inferior se sincroniza entre dispositivos vía
// preferences jsonb del usuario (users/me/nav_preferences). navPreferences
// (local) sigue siendo el cache offline-first: se lee de entrada para pintar
// sin esperar red, se sobreescribe si el server tiene algo distinto, y cada
// cambio se guarda local + se empuja al server en background.
class NavCustomizationViewModel(
    private val scope: CoroutineScope,
    private val navPreferences: NavPreferences,
    private val api: FinancePyApi,
    private val businessModeEnabled: Boolean
) {
    private val pool = NavItems.pool(businessModeEnabled)

    private val _uiState = MutableStateFlow(
        NavCustomizationUiState(
            pool = pool,
            selectedIds = loadInitialSelection()
        )
    )
    val uiState: StateFlow<NavCustomizationUiState> = _uiState.asStateFlow()

    init {
        syncFromServer()
    }

    private fun syncFromServer() {
        scope.launch {
            try {
                val remoteOrder = api.fetchNavItemOrder()
                val poolIds = pool.map { it.id }.toSet()
                val filtered = remoteOrder?.filter { it in poolIds }
                if (!filtered.isNullOrEmpty() && filtered != _uiState.value.selectedIds) {
                    navPreferences.saveOrder(filtered)
                    _uiState.value = _uiState.value.copy(selectedIds = filtered)
                }
            } catch (e: Exception) {
                // Sin conexión o error de red: seguimos con el cache local.
            }
        }
    }

    private fun persist(order: List<String>) {
        navPreferences.saveOrder(order)
        scope.launch {
            try {
                api.updateNavItemOrder(order)
            } catch (e: Exception) {
                // Falla silenciosa: el cambio queda local, se re-sincroniza
                // en el próximo syncFromServer (próxima apertura de pantalla).
            }
        }
    }

    private fun loadInitialSelection(): List<String> {
        val saved = navPreferences.loadOrder()
        val poolIds = pool.map { it.id }.toSet()
        // Filtrar por si cambió business_mode_enabled desde la última vez que
        // se guardó la selección (un ítem de negocio guardado ya no aplica).
        val filtered = saved?.filter { it in poolIds }
        return if (filtered.isNullOrEmpty()) NavItems.CORE_DEFAULT_ORDER.filter { it in poolIds } else filtered
    }

    fun toggle(itemId: String) {
        val current = _uiState.value.selectedIds
        val next = if (itemId in current) {
            current - itemId
        } else {
            if (current.size >= _uiState.value.maxSelectable) return
            current + itemId
        }
        _uiState.value = _uiState.value.copy(selectedIds = next)
        persist(next)
    }

    fun moveUp(itemId: String) {
        val current = _uiState.value.selectedIds.toMutableList()
        val idx = current.indexOf(itemId)
        if (idx <= 0) return
        current.removeAt(idx)
        current.add(idx - 1, itemId)
        _uiState.value = _uiState.value.copy(selectedIds = current)
        persist(current)
    }

    fun moveDown(itemId: String) {
        val current = _uiState.value.selectedIds.toMutableList()
        val idx = current.indexOf(itemId)
        if (idx < 0 || idx >= current.size - 1) return
        current.removeAt(idx)
        current.add(idx + 1, itemId)
        _uiState.value = _uiState.value.copy(selectedIds = current)
        persist(current)
    }

    fun resetToDefault() {
        val poolIds = pool.map { it.id }.toSet()
        val defaults = NavItems.CORE_DEFAULT_ORDER.filter { it in poolIds }
        _uiState.value = _uiState.value.copy(selectedIds = defaults)
        persist(defaults)
    }
}
