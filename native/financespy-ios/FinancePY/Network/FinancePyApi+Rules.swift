import Foundation

// MARK: - Rules DTOs

struct RuleDto: Codable, Identifiable {
    let id: String
    let name: String?
    let resourceType: String
    let active: Bool
    let effectiveDate: String?
    let conditions: [RuleConditionDto]
    let actions: [RuleActionDto]
    let createdAt: String
    let updatedAt: String
}

struct RuleConditionDto: Codable, Identifiable {
    let id: String
    let conditionType: String
    let operatorStr: String
    let value: String?
    let subConditions: [RuleConditionDto]?

    enum CodingKeys: String, CodingKey {
        case id, value
        case conditionType = "condition_type"
        case operatorStr = "operator"
        case subConditions = "sub_conditions"
    }
}

struct RuleActionDto: Codable, Identifiable {
    let id: String
    let actionType: String
    let value: String?

    enum CodingKeys: String, CodingKey {
        case id, value
        case actionType = "action_type"
    }
}

struct RuleFilterDto: Codable, Identifiable {
    let type: String
    let key: String
    let label: String
    let operators: [[String]]?
    let options: [[String]]?
    let numberStep: Double?

    var id: String { key }
}

struct RuleExecutorDto: Codable, Identifiable {
    let type: String
    let key: String
    let label: String
    let options: [[String]]?

    var id: String { key }
}

struct RuleRegistryDto: Codable {
    let filters: [RuleFilterDto]
    let executors: [RuleExecutorDto]
}

struct RulesResponseDto: Codable {
    let data: [RuleDto]
}

struct CreateRuleRequest: Codable {
    let rule: CreateRuleBody
}

struct CreateRuleBody: Codable {
    let name: String?
    let resourceType: String
    let active: Bool
    let effectiveDate: String?
    let conditionsAttributes: [ConditionAttributes]
    let actionsAttributes: [ActionAttributes]
}

struct ConditionAttributes: Codable {
    let conditionType: String
    let operatorStr: String
    let value: String?
    let subConditionsAttributes: [ConditionAttributes]?
    let id: String?
    let destroy: Bool?

    enum CodingKeys: String, CodingKey {
        case value, id
        case conditionType = "condition_type"
        case operatorStr = "operator"
        case subConditionsAttributes = "sub_conditions_attributes"
        case destroy = "_destroy"
    }
}

struct ActionAttributes: Codable {
    let actionType: String
    let value: String
    let id: String?
    let destroy: Bool?

    enum CodingKeys: String, CodingKey {
        case value, id
        case actionType = "action_type"
        case destroy = "_destroy"
    }
}

struct UpdateRuleRequest: Codable {
    let rule: UpdateRuleBody
}

struct UpdateRuleBody: Codable {
    let name: String?
    let active: Bool?
    let effectiveDate: String?
    let conditionsAttributes: [ConditionAttributes]?
    let actionsAttributes: [ActionAttributes]?
}

// MARK: - Rules API Methods

extension FinancePyApi {
    func getRuleRegistry(resourceType: String = "transaction") async throws -> RuleRegistryDto {
        let queryItems = [URLQueryItem(name: "resource_type", value: resourceType)]
        return try await client.request(path: "/api/v1/rules/registry", queryItems: queryItems)
    }

    func getRules(resourceType: String = "transaction", page: Int = 1, perPage: Int = 100) async throws -> [RuleDto] {
        let queryItems = [
            URLQueryItem(name: "resource_type", value: resourceType),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "per_page", value: String(perPage))
        ]
        let response: RulesResponseDto = try await client.request(path: "/api/v1/rules", queryItems: queryItems)
        return response.data
    }

    func getRule(id: String) async throws -> RuleDto {
        return try await client.request(path: "/api/v1/rules/\(id)")
    }

    func createRule(request: CreateRuleRequest) async throws -> RuleDto {
        return try await client.request(method: "POST", path: "/api/v1/rules", body: request)
    }

    func updateRule(id: String, request: UpdateRuleRequest) async throws -> RuleDto {
        return try await client.request(method: "PATCH", path: "/api/v1/rules/\(id)", body: request)
    }

    func deleteRule(id: String) async throws {
        let _: EmptyResponse = try await client.request(method: "DELETE", path: "/api/v1/rules/\(id)")
    }
}
