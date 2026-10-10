import Foundation

struct FleetVehiclesEnvelope: Codable {
    let data: [FleetVehicleDto]
    let meta: FleetVehiclesMetaDto?
}

struct FleetVehiclesMetaDto: Codable {
    let currentPage: Int
    let nextPage: Int?
    let prevPage: Int?
    let totalPages: Int
    let totalCount: Int
}

struct FleetVehicleEnvelope: Codable {
    let data: FleetVehicleDto
}

struct FuelLogEnvelope: Codable {
    let data: FuelLogDto
}

struct FleetVehicleDto: Codable, Identifiable {
    let id: String
    let plate: String
    let brand: String
    let model: String
    let year: Int?
    let status: String
    let notes: String?
    let createdAt: String?
    let updatedAt: String?
    let averageFuelEfficiency: [String: Double]?
    let monthlyFuelConsumed: [String: Double]?
    let monthlyDistance: [String: Double]?
    let fuelLogs: [FuelLogDto]?
}

struct FuelLogDto: Codable, Identifiable {
    let id: String
    let fleetVehicleId: String
    let accountId: String
    let loggedAt: String
    let odometer: Double?
    let liters: Double
    let cost: Double
    let notes: String?
    let entryId: String?
    let createdAt: String?
    let updatedAt: String?
    let fuelLogLines: [FuelLogLineDto]?
}

struct FuelLogLineDto: Codable, Identifiable {
    let id: String?
    let fuelType: String
    let brand: String?
    let liters: Double
    let cost: Double
}

struct CreateFleetVehicleRequest: Codable {
    let fleetVehicle: CreateFleetVehicleBody
}

struct CreateFleetVehicleBody: Codable {
    let plate: String
    let brand: String
    let model: String
    let year: Int?
    let status: String?
    let notes: String?
}

struct CreateFuelLogRequest: Codable {
    let fuelLog: CreateFuelLogBody
}

struct CreateFuelLogLineBody: Codable {
    let fuelType: String
    let brand: String?
    let liters: Double
    let cost: Double
}

struct CreateFuelLogBody: Codable {
    let accountId: String
    let loggedAt: String
    let odometer: Double?
    let liters: Double?
    let cost: Double?
    let notes: String?
    let fuelLogLines: [CreateFuelLogLineBody]
}
