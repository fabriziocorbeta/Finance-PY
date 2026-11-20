package py.com.cdco.financespy.screens

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.api.dto.CreateFleetVehicleBody
import py.com.cdco.financespy.api.dto.FleetVehicleDto
import py.com.cdco.financespy.sync.OfflineCache
import py.com.cdco.financespy.sync.OfflineCacheKeys
import py.com.cdco.financespy.sync.OfflineStore

class FleetListViewModel(
    private val scope: CoroutineScope,
    private val api: FinancePyApi,
    store: OfflineStore? = null
) {
    private val cache = OfflineCache(store)
    private val _vehicles = MutableStateFlow(
        cache.getList(OfflineCacheKeys.FLEET_VEHICLES_LIST, FleetVehicleDto.serializer()) ?: emptyList()
    )
    val vehicles: StateFlow<List<FleetVehicleDto>> = _vehicles.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _error = MutableStateFlow<String?>(null)
    val error: StateFlow<String?> = _error.asStateFlow()

    init {
        refresh()
    }

    fun refresh() {
        scope.launch {
            _isLoading.value = true
            _error.value = null
            runCatching {
                api.fetchFleetVehicles()
            }.onSuccess { list ->
                _vehicles.value = list
                cache.putList(OfflineCacheKeys.FLEET_VEHICLES_LIST, FleetVehicleDto.serializer(), list)
            }.onFailure { throwable ->
                if (_vehicles.value.isEmpty()) {
                    _error.value = throwable.message ?: "Error al cargar los vehículos"
                }
            }
            _isLoading.value = false
        }
    }

    fun createVehicle(
        plate: String,
        brand: String,
        model: String,
        year: Int?,
        status: String,
        notes: String?,
        onSuccess: () -> Unit
    ) {
        scope.launch {
            _isLoading.value = true
            _error.value = null
            runCatching {
                api.createFleetVehicle(
                    CreateFleetVehicleBody(
                        plate = plate,
                        brand = brand,
                        model = model,
                        year = year,
                        status = status,
                        notes = notes
                    )
                )
            }.onSuccess {
                refresh()
                onSuccess()
            }.onFailure { throwable ->
                _error.value = throwable.message ?: "Error al crear el vehículo"
                _isLoading.value = false
            }
        }
    }
}
