package py.com.cdco.financespy.api.dto

import kotlinx.serialization.Serializable

@Serializable
data class FleetVehicleDto(
    val id: String,
    val family_id: String? = null,
    val plate: String,
    val brand: String,
    val model: String,
    val year: Int? = null,
    val status: String = "active",
    val notes: String? = null,
    val average_fuel_efficiency: Map<String, Double> = emptyMap(),
    val monthly_fuel_consumed: Map<String, Double> = emptyMap(),
    val monthly_distance: Map<String, Double> = emptyMap(),
    val fuel_logs: List<FuelLogDto> = emptyList(),
    val created_at: String? = null,
    val updated_at: String? = null
)

@Serializable
data class FuelLogDto(
    val id: String,
    val fleet_vehicle_id: String,
    val account_id: String,
    val entry_id: String? = null,
    val odometer: Double? = null,
    val logged_at: String,
    val notes: String? = null,
    val liters: Double = 0.0,
    val cost: Double = 0.0,
    val fuel_log_lines: List<FuelLogLineDto> = emptyList(),
    val created_at: String? = null,
    val updated_at: String? = null
)

@Serializable
data class FuelLogLineDto(
    val id: String? = null,
    val fuel_log_id: String? = null,
    val fuel_type: String = "nafta",
    val brand: String? = null,
    val liters: Double = 0.0,
    val cost: Double = 0.0,
    val created_at: String? = null,
    val updated_at: String? = null
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
data class CreateFleetVehicleRequest(
    val fleet_vehicle: CreateFleetVehicleBody
)

@Serializable
data class UpdateFleetVehicleBody(
    val plate: String? = null,
    val brand: String? = null,
    val model: String? = null,
    val year: Int? = null,
    val status: String? = null,
    val notes: String? = null
)

@Serializable
data class UpdateFleetVehicleRequest(
    val fleet_vehicle: UpdateFleetVehicleBody
)

@Serializable
data class CreateFuelLogLineBody(
    val id: String? = null,
    val fuel_type: String = "nafta",
    val brand: String? = null,
    val liters: Double,
    val cost: Double,
    val _destroy: Boolean? = null
)

@Serializable
data class CreateFuelLogBody(
    val account_id: String,
    val logged_at: String,
    val odometer: Double? = null,
    val notes: String? = null,
    val fuel_log_lines_attributes: List<CreateFuelLogLineBody> = emptyList()
)

@Serializable
data class CreateFuelLogRequest(
    val fuel_log: CreateFuelLogBody
)

@Serializable
data class FleetVehicleEnvelope(
    val data: FleetVehicleDto
)

@Serializable
data class FleetVehiclesMetaDto(
    val current_page: Int,
    val next_page: Int? = null,
    val prev_page: Int? = null,
    val total_pages: Int,
    val total_count: Int,
    val per_page: Int
)

@Serializable
data class FleetVehiclesEnvelope(
    val data: List<FleetVehicleDto>,
    val meta: FleetVehiclesMetaDto? = null
)

@Serializable
data class FuelLogEnvelope(
    val data: FuelLogDto
)
