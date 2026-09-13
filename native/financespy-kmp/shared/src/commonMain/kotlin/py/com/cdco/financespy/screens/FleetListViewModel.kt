package py.com.cdco.financespy.screens

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.api.dto.CreateFleetVehicleBody
import py.com.cdco.financespy.api.dto.FleetVehicleDto

class FleetListViewModel(
    private val api: FinancePyApi,
    private val scope: CoroutineScope = CoroutineScope(Dispatchers.Main)
) {
    private val _vehicles = MutableStateFlow<List<FleetVehicleDto>>(emptyList())
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
            try {
                val fetched = api.fetchAllFleetVehicles()
                _vehicles.value = fetched
            } catch (e: Exception) {
                _error.value = e.message ?: "Error al cargar vehículos"
            } finally {
                _isLoading.value = false
            }
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
            try {
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
                refresh()
                onSuccess()
            } catch (e: Exception) {
                _error.value = e.message ?: "Error al crear vehículo"
            } finally {
                _isLoading.value = false
            }
        }
    }
}
