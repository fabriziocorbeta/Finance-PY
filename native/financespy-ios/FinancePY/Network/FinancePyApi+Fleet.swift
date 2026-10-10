import Foundation

extension FinancePyApi {
    func fetchFleetVehicles() async throws -> [FleetVehicleDto] {
        var allVehicles: [FleetVehicleDto] = []
        var page = 1
        var totalPages = 1

        repeat {
            let queryItems = [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "per_page", value: "100")
            ]

            let response: FleetVehiclesEnvelope = try await ApiClient.shared.request(path: "/api/v1/fleet_vehicles", queryItems: queryItems)
            allVehicles.append(contentsOf: response.data)
            totalPages = response.meta?.totalPages ?? 1
            page += 1
        } while page <= totalPages

        return allVehicles
    }

    func fetchFleetVehicle(id: String) async throws -> FleetVehicleDto {
        let response: FleetVehicleEnvelope = try await ApiClient.shared.request(path: "/api/v1/fleet_vehicles/\(id)")
        return response.data
    }

    func createFleetVehicle(request: CreateFleetVehicleRequest) async throws -> FleetVehicleDto {
        let response: FleetVehicleEnvelope = try await ApiClient.shared.request(
            method: "POST",
            path: "/api/v1/fleet_vehicles",
            body: request
        )
        return response.data
    }

    func updateFleetVehicle(id: String, request: CreateFleetVehicleRequest) async throws -> FleetVehicleDto {
        let response: FleetVehicleEnvelope = try await ApiClient.shared.request(
            method: "PUT",
            path: "/api/v1/fleet_vehicles/\(id)",
            body: request
        )
        return response.data
    }

    func deleteFleetVehicle(id: String) async throws {
        let _: EmptyResponse = try await ApiClient.shared.request(
            method: "DELETE",
            path: "/api/v1/fleet_vehicles/\(id)"
        )
    }

    func createFuelLog(vehicleId: String, request: CreateFuelLogRequest) async throws -> FuelLogDto {
        let response: FuelLogEnvelope = try await ApiClient.shared.request(
            method: "POST",
            path: "/api/v1/fleet_vehicles/\(vehicleId)/fuel_logs",
            body: request
        )
        return response.data
    }

    func updateFuelLog(vehicleId: String, logId: String, request: CreateFuelLogRequest) async throws -> FuelLogDto {
        let response: FuelLogEnvelope = try await ApiClient.shared.request(
            method: "PUT",
            path: "/api/v1/fleet_vehicles/\(vehicleId)/fuel_logs/\(logId)",
            body: request
        )
        return response.data
    }

    func deleteFuelLog(vehicleId: String, logId: String) async throws {
        let _: EmptyResponse = try await ApiClient.shared.request(
            method: "DELETE",
            path: "/api/v1/fleet_vehicles/\(vehicleId)/fuel_logs/\(logId)"
        )
    }
}
