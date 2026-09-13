package py.com.cdco.financespy.screens

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
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
    val vehicleId: String,
    private val api: FinancePyApi,
    private val scope: CoroutineScope = CoroutineScope(Dispatchers.Main)
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
            try {
                val fetched = api.fetchFleetVehicle(vehicleId)
                _vehicle.value = fetched
            } catch (e: Exception) {
                _error.value = e.message ?: "Error al cargar detalle del vehículo"
            } finally {
                _isLoading.value = false
            }
        }
    }

    private fun loadAccounts() {
        scope.launch {
            try {
                _accounts.value = api.fetchAllAccounts()
            } catch (_: Exception) {}
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
            try {
                val lineBody = CreateFuelLogLineBody(
                    fuel_type = fuelType,
                    brand = brand,
                    liters = liters,
                    cost = cost
                )
                val body = CreateFuelLogBody(
                    account_id = accountId,
                    logged_at = loggedAt,
                    odometer = odometer,
                    notes = notes,
                    fuel_log_lines_attributes = listOf(lineBody)
                )
                api.createFuelLog(vehicleId, body)
                refresh()
                onSuccess()
            } catch (e: Exception) {
                _error.value = e.message ?: "Error al registrar combustible"
            } finally {
                _isLoading.value = false
            }
        }
    }

    fun deleteFuelLog(logId: String) {
        scope.launch {
            _isLoading.value = true
            try {
                api.deleteFuelLog(vehicleId, logId)
                refresh()
            } catch (e: Exception) {
                _error.value = e.message ?: "Error al eliminar carga"
            } finally {
                _isLoading.value = false
            }
        }
    }
}
