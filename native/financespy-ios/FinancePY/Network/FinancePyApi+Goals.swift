import Foundation

// MARK: - Goal DTOs

struct GoalDto: Codable, Identifiable {
    let id: String
    let name: String
    @AnyStringAmount var targetAmount: String?
    let currency: String?
    let targetDate: String?
    let color: String?
    let icon: String?
    let notes: String?
    let state: String?
    let progressBasis: String?
    @AnyStringAmount var currentBalance: String?
    let currentBalanceCents: Int64?
    @AnyStringAmount var remainingAmount: String?
    let remainingAmountCents: Int64?
    let progressPercent: Int?
    let pace: String?
    let status: String?
    let monthsRemaining: Int?
    @AnyStringAmount var catchUpDelta: String?
    let accountIds: [String]?
    let allocations: [String: String?]?
}

struct GoalPledgeDto: Codable, Identifiable {
    let id: String
    let goalId: String?
    let accountId: String?
    @AnyStringAmount var amount: String?
    let currency: String?
    let kind: String?
    let status: String?
    let expiresAt: String?
    let daysLeft: Int?
    let accountName: String?
}

struct GoalsResponse: Codable {
    let data: [GoalDto]
    let meta: PaginationDto?
}

struct GoalSingleResponse: Codable {
    let data: GoalDto
}

struct GoalPledgesResponse: Codable {
    let data: [GoalPledgeDto]
    let meta: PaginationDto?
}

struct GoalPledgeSingleResponse: Codable {
    let data: GoalPledgeDto
}

struct GoalAccountAttributeDto: Codable {
    let accountId: String
    let allocatedAmount: String?

    enum CodingKeys: String, CodingKey {
        case accountId = "account_id"
        case allocatedAmount = "allocated_amount"
    }
}

struct CreateGoalBody: Codable {
    let name: String
    let targetAmount: String
    let currency: String?
    let targetDate: String?
    let color: String?
    let icon: String?
    let notes: String?
    let accountIds: [String]?
    let allocations: [String: String]?
    let goalAccountsAttributes: [GoalAccountAttributeDto]?

    enum CodingKeys: String, CodingKey {
        case name, currency, color, icon, notes, allocations
        case targetAmount = "target_amount"
        case targetDate = "target_date"
        case accountIds = "account_ids"
        case goalAccountsAttributes = "goal_accounts_attributes"
    }
}

struct UpdateGoalBody: Codable {
    let name: String?
    let targetAmount: String?
    let currency: String?
    let targetDate: String?
    let color: String?
    let icon: String?
    let notes: String?
    let state: String?
    let accountIds: [String]?
    let allocations: [String: String]?
    let goalAccountsAttributes: [GoalAccountAttributeDto]?

    enum CodingKeys: String, CodingKey {
        case name, currency, color, icon, notes, state, allocations
        case targetAmount = "target_amount"
        case targetDate = "target_date"
        case accountIds = "account_ids"
        case goalAccountsAttributes = "goal_accounts_attributes"
    }
}

struct CreateGoalPledgeBody: Codable {
    let amount: Double
    let accountId: String

    enum CodingKeys: String, CodingKey {
        case amount
        case accountId = "account_id"
    }
}

// MARK: - Extension for API Service

extension FinancePyApi {
    func fetchGoals() async throws -> [GoalDto] {
        let response: GoalsResponse = try await ApiClient.shared.request(path: "/api/v1/goals")
        return response.data
    }

    func fetchGoal(id: String) async throws -> GoalDto {
        let response: GoalSingleResponse = try await ApiClient.shared.request(path: "/api/v1/goals/\(id)")
        return response.data
    }

    func createGoal(body: CreateGoalBody) async throws -> GoalDto {
        let response: GoalSingleResponse = try await ApiClient.shared.request(method: "POST", path: "/api/v1/goals", body: body)
        return response.data
    }

    func updateGoal(id: String, body: UpdateGoalBody) async throws -> GoalDto {
        let response: GoalSingleResponse = try await ApiClient.shared.request(method: "PATCH", path: "/api/v1/goals/\(id)", body: body)
        return response.data
    }

    func deleteGoal(id: String) async throws {
        let _: EmptyResponse = try await ApiClient.shared.request(method: "DELETE", path: "/api/v1/goals/\(id)")
    }

    func fetchGoalPledges(goalId: String) async throws -> [GoalPledgeDto] {
        let response: GoalPledgesResponse = try await ApiClient.shared.request(path: "/api/v1/goals/\(goalId)/pledges")
        return response.data
    }

    func createGoalPledge(goalId: String, body: CreateGoalPledgeBody) async throws -> GoalPledgeDto {
        let response: GoalPledgeSingleResponse = try await ApiClient.shared.request(method: "POST", path: "/api/v1/goals/\(goalId)/pledges", body: body)
        return response.data
    }

    func cancelGoalPledge(goalId: String, pledgeId: String) async throws {
        let _: EmptyResponse = try await ApiClient.shared.request(method: "DELETE", path: "/api/v1/goals/\(goalId)/pledges/\(pledgeId)")
    }

    func renewGoalPledge(goalId: String, pledgeId: String) async throws -> GoalPledgeDto {
        let response: GoalPledgeSingleResponse = try await ApiClient.shared.request(method: "PATCH", path: "/api/v1/goals/\(goalId)/pledges/\(pledgeId)/renew")
        return response.data
    }
}
