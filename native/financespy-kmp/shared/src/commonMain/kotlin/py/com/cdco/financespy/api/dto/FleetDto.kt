package py.com.cdco.financespy.api.dto

import kotlinx.serialization.Serializable

@Serializable
data class FleetVehiclesEnvelope(
    val data: List<FleetVehicleDto>,
    val meta: FleetMetaDto
)

@Serializable
data class FleetMetaDto(
    val current_page: Int,
    val next_page: Int? = null,
    val prev_page: Int? = null,
    val total_pages: Int,
    val total_count: Int,
    val per_page: Int
)

@Serializable
data class FleetVehicleDto(
    val id: String,
    val plate: String,
    val brand: String,
    val model: String,
    val year: Int? = null,
    val status: String = "active",
    val notes: String? = null,
    val created_at: String? = null,
    val updated_at: String? = null,
    val average_fuel_efficiency: Map<String, Double> = emptyMap(),
    val monthly_fuel_consumed: Map<String, Double> = emptyMap(),
    val monthly_distance: Map<String, Double> = emptyMap(),
    val fuel_logs: List<FuelLogDto> = emptyList()
)

@Serializable
data class FuelLogDto(
    val id: String,
    val fleet_vehicle_id: String,
    val account_id: String,
    val entry_id: String? = null,
    val liters: Double,
    val cost: Double,
    val odometer: Int? = null,
    val logged_at: String,
    val notes: String? = null,
    val created_at: String? = null,
    val updated_at: String? = null,
    val fuel_log_lines: List<FuelLogLineDto> = emptyList()
)

@Serializable
data class FuelLogLineDto(
    val id: String,
    val fuel_type: String,
    val brand: String? = null,
    val liters: Double,
    val cost: Double,
    val created_at: String? = null,
    val updated_at: String? = null
)

@Serializable
data class CreateFleetVehicleRequest(
    val fleet_vehicle: CreateFleetVehicleBody
)

@Serializable
data class CreateFleetVehicleBody(
    val plate: String,
    val brand: String,
    val model: String,
    val year: Int? = null,
    val status: String = "active",
    val notes: String? = null
)

@Serializable
data class CreateFuelLogRequest(
    val fuel_log: CreateFuelLogBody
)

@Serializable
data class CreateFuelLogBody(
    val account_id: String,
    val logged_at: String,
    val odometer: Int? = null,
    val notes: String? = null,
    val fuel_log_lines: List<CreateFuelLogLineBody>
)

@Serializable
data class CreateFuelLogLineBody(
    val fuel_type: String,
    val brand: String? = null,
    val liters: Double,
    val cost: Double
)
