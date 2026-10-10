import Foundation

// MARK: - Goal DTOs

struct GoalDto: Codable, Identifiable {
    let id: String
    let name: String
    let targetAmount: String?
    let currency: String?
    let targetDate: String?
    let color: String?
    let icon: String?
    let notes: String?
    let state: String?
    let progressBasis: String?
    let currentBalance: String?
    let currentBalanceCents: Int64?
    let remainingAmount: String?
    let remainingAmountCents: Int64?
    let progressPercent: Int?
    let pace: String?
    let status: String?
    let monthsRemaining: Int?
    let catchUpDelta: String?
    let accountIds: [String]?
    let allocations: [String: String?]?

    enum CodingKeys: String, CodingKey {
        case id, name, currency, color, icon, notes, state, pace, status, allocations
        case targetAmount = "target_amount"
        case targetDate = "target_date"
        case progressBasis = "progress_basis"
        case currentBalance = "current_balance"
        case currentBalanceCents = "current_balance_cents"
        case remainingAmount = "remaining_amount"
        case remainingAmountCents = "remaining_amount_cents"
        case progressPercent = "progress_percent"
        case monthsRemaining = "months_remaining"
        case catchUpDelta = "catch_up_delta"
        case accountIds = "account_ids"
    }
}

struct GoalPledgeDto: Codable, Identifiable {
    let id: String
    let amount: String?
    let amountCents: Int64?
    let currency: String?
    let state: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, amount, currency, state
        case amountCents = "amount_cents"
        case createdAt = "created_at"
    }
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
        return try await ApiClient.shared.request(path: "/api/v1/goals")
    }

    func fetchGoal(id: String) async throws -> GoalDto {
        return try await ApiClient.shared.request(path: "/api/v1/goals/\(id)")
    }

    func createGoal(body: CreateGoalBody) async throws -> GoalDto {
        return try await ApiClient.shared.request(path: "/api/v1/goals", method: "POST", body: body)
    }

    func updateGoal(id: String, body: UpdateGoalBody) async throws -> GoalDto {
        return try await ApiClient.shared.request(path: "/api/v1/goals/\(id)", method: "PATCH", body: body)
    }

    func deleteGoal(id: String) async throws {
        _ = try await ApiClient.shared.requestEmpty(path: "/api/v1/goals/\(id)", method: "DELETE")
    }

    func fetchGoalPledges(goalId: String) async throws -> [GoalPledgeDto] {
        return try await ApiClient.shared.request(path: "/api/v1/goals/\(goalId)/pledges")
    }

    func createGoalPledge(goalId: String, body: CreateGoalPledgeBody) async throws -> GoalPledgeDto {
        return try await ApiClient.shared.request(path: "/api/v1/goals/\(goalId)/pledges", method: "POST", body: body)
    }

    func cancelGoalPledge(goalId: String, pledgeId: String) async throws {
        _ = try await ApiClient.shared.requestEmpty(path: "/api/v1/goals/\(goalId)/pledges/\(pledgeId)", method: "DELETE")
    }

    func renewGoalPledge(goalId: String, pledgeId: String) async throws -> GoalPledgeDto {
        return try await ApiClient.shared.request(path: "/api/v1/goals/\(goalId)/pledges/\(pledgeId)/renew", method: "PATCH")
    }
}
