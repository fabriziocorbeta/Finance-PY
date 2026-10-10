import Foundation

// MARK: - Usage DTOs

struct UsageDto: Codable {
    let authenticationMethod: String?
    let message: String?
}

// MARK: - Users & Family Settings DTOs

struct UpdateFamilyAttributesDto: Codable {
    var moniker: String?
    var name: String?
    var country: String?
    var currency: String?
    var locale: String?
    var dateFormat: String?
}

struct UpdateUserBody: Codable {
    var firstName: String?
    var lastName: String?
    var theme: String?
    var locale: String?
    var goals: [String]?
    var setOnboardingPreferencesAt: String?
    var setOnboardingGoalsAt: String?
    var onboardedAt: String?
    var familyAttributes: UpdateFamilyAttributesDto?
}

struct UpdateUserRequest: Codable {
    let user: UpdateUserBody
}

struct UserDto: Codable, Identifiable {
    let id: String
    let email: String
    let firstName: String?
    let lastName: String?
    let displayName: String?
    let role: String
    let theme: String?
    let goals: [String]?
    let onboardedAt: String?
    let needsOnboarding: Bool?
    let isInvited: Bool?
}

struct FamilySettingsDto: Codable {
    let id: String
    let name: String?
    let currency: String
    let locale: String
    let dateFormat: String
    let country: String?
    let timezone: String?
    let monthStartDay: Int
    let moniker: String?
    let defaultAccountSharing: String?
    let businessModeEnabled: Bool
    let customEnabledCurrencies: Bool
    let enabledCurrencies: [String]
    let createdAt: String
    let updatedAt: String
    let currentUser: UserDto?
    let users: [UserDto]
}

struct NavPreferencesDto: Codable {
    let navItemOrder: [String]?
}

// MARK: - FinancePyApi Extensions

extension FinancePyApi {

    @discardableResult
    func updateUser(body: UpdateUserBody) async throws -> FamilySettingsDto {
        return try await ApiClient.shared.request(
            method: "PATCH",
            path: "/api/v1/users/me",
            body: UpdateUserRequest(user: body)
        )
    }

    func fetchNavPreferences() async throws -> NavPreferencesDto {
        return try await ApiClient.shared.request(path: "/api/v1/users/me/nav_preferences")
    }

    @discardableResult
    func updateNavPreferences(itemIds: [String]) async throws -> NavPreferencesDto {
        return try await ApiClient.shared.request(
            method: "PUT",
            path: "/api/v1/users/me/nav_preferences",
            body: NavPreferencesDto(navItemOrder: itemIds)
        )
    }

    func fetchFamilySettings() async throws -> FamilySettingsDto {
        return try await ApiClient.shared.request(path: "/api/v1/family_settings")
    }

    func fetchUsage() async throws -> UsageDto {
        return try await ApiClient.shared.request(path: "/api/v1/usage")
    }

    func deleteAccount() async throws {
        let _: EmptyResponse = try await ApiClient.shared.request(method: "DELETE", path: "/api/v1/users/me")
    }

    func resetData() async throws {
        let _: EmptyResponse = try await ApiClient.shared.request(method: "DELETE", path: "/api/v1/users/reset")
    }
}
