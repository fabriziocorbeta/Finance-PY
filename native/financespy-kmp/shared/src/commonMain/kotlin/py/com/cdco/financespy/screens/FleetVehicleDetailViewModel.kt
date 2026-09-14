package py.com.cdco.financespy.screens

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.api.dto.AccountDto
import py.com.cdco.financespy.api.dto.CreateFuelLogBody
import py.com.cdco.financespy.api.dto.CreateFuelLogLineBody
import py.com.cdco.financespy.api.dto.FleetVehicleDto

class FleetVehicleDetailViewModel(
    private val scope: CoroutineScope,
    private val vehicleId: String,
    private val api: FinancePyApi
) {
    private val _vehicle = MutableStateFlow<FleetVehicleDto?>(null)
    val vehicle: StateFlow<FleetVehicleDto?> = _vehicle.asStateFlow()

    private val _accounts = MutableStateFlow<List<AccountDto>>(emptyList())
    val accounts: StateFlow<List<AccountDto>> = _accounts.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _error = MutableStateFlow<String?>(null)
    val error: StateFlow<String?> = _error.asStateFlow()

    init {
        refresh()
        loadAccounts()
    }

    fun refresh() {
        scope.launch {
            _isLoading.value = true
            _error.value = null
            runCatching {
                api.fetchFleetVehicle(vehicleId)
            }.onSuccess { detail ->
                _vehicle.value = detail
            }.onFailure { throwable ->
                _error.value = throwable.message ?: "Error al cargar el vehículo"
            }
            _isLoading.value = false
        }
    }

    private fun loadAccounts() {
        scope.launch {
            runCatching {
                api.fetchAllAccounts()
            }.onSuccess { list ->
                _accounts.value = list
            }
        }
    }

    fun createFuelLog(
        accountId: String,
        loggedAt: String,
        odometer: Double?,
        fuelType: String,
        brand: String?,
        liters: Double,
        cost: Double,
        notes: String?,
        onSuccess: () -> Unit
    ) {
        scope.launch {
            _isLoading.value = true
            _error.value = null
            runCatching {
                api.createFuelLog(
                    vehicleId = vehicleId,
                    body = CreateFuelLogBody(
                        account_id = accountId,
                        logged_at = loggedAt,
                        odometer = odometer,
                        notes = notes,
                        fuel_log_lines = listOf(
                            CreateFuelLogLineBody(
                                fuel_type = fuelType,
                                brand = brand,
                                liters = liters,
                                cost = cost
                            )
                        )
                    )
                )
            }.onSuccess {
                refresh()
                onSuccess()
            }.onFailure { throwable ->
                _error.value = throwable.message ?: "Error al guardar el registro de combustible"
                _isLoading.value = false
            }
        }
    }

    fun deleteFuelLog(fuelLogId: String, onSuccess: () -> Unit) {
        scope.launch {
            _isLoading.value = true
            _error.value = null
            runCatching {
                api.deleteFuelLog(vehicleId, fuelLogId)
            }.onSuccess {
                refresh()
                onSuccess()
            }.onFailure { throwable ->
                _error.value = throwable.message ?: "Error al eliminar el registro de combustible"
                _isLoading.value = false
            }
        }
    }
}
