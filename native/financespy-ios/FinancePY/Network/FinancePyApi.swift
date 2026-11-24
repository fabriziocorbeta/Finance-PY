import Foundation

// MARK: - DTOs

struct AccountsResponse: Codable {
    let accounts: [AccountDto]
    let pagination: PaginationDto
}

struct AccountDto: Codable {
    let id: String
    let name: String
    let balanceCents: Int64
    let cashBalanceCents: Int64
    let currency: String
    let classification: String
    let accountType: String
    let subtype: String?
    let status: String
    let updatedAt: String
}

struct PaginationDto: Codable {
    let currentPage: Int
    let nextPage: Int?
    let prevPage: Int?
    let totalPages: Int
    let totalCount: Int
    let perPage: Int

    init(page: Int, perPage: Int, totalCount: Int, totalPages: Int, nextPage: Int? = nil, prevPage: Int? = nil) {
        self.currentPage = page
        self.perPage = perPage
        self.totalCount = totalCount
        self.totalPages = totalPages
        self.nextPage = nextPage
        self.prevPage = prevPage
    }

    private enum CodingKeys: String, CodingKey {
        case currentPage, page, nextPage, prevPage, totalPages, totalCount, perPage
    }

    // `meta` envelopes (budgets, products, goals) send `current_page`; `pagination`
    // envelopes (accounts, transactions, chats) send `page`. Accept either.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currentPage = try container.decodeIfPresent(Int.self, forKey: .currentPage)
            ?? container.decodeIfPresent(Int.self, forKey: .page) ?? 1
        nextPage = try container.decodeIfPresent(Int.self, forKey: .nextPage)
        prevPage = try container.decodeIfPresent(Int.self, forKey: .prevPage)
        totalPages = try container.decodeIfPresent(Int.self, forKey: .totalPages) ?? 1
        totalCount = try container.decodeIfPresent(Int.self, forKey: .totalCount) ?? 0
        perPage = try container.decodeIfPresent(Int.self, forKey: .perPage) ?? 25
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(currentPage, forKey: .currentPage)
        try container.encodeIfPresent(nextPage, forKey: .nextPage)
        try container.encodeIfPresent(prevPage, forKey: .prevPage)
        try container.encode(totalPages, forKey: .totalPages)
        try container.encode(totalCount, forKey: .totalCount)
        try container.encode(perPage, forKey: .perPage)
    }
}

struct BalanceSheetResponse: Codable {
    let currency: String
    let netWorth: MoneyDto
    let assets: MoneyDto
    let liabilities: MoneyDto
}

struct MoneyDto: Codable {
    let cents: Int64?
    @AnyStringAmount var amount: String?
    let currency: String?
    let formatted: String?

    init(
        cents: Int64? = nil,
        amount: AnyStringAmount = AnyStringAmount(wrappedValue: nil),
        currency: String? = nil,
        formatted: String? = nil
    ) {
        self.cents = cents
        self._amount = amount
        self.currency = currency
        self.formatted = formatted
    }
}

struct TransactionsResponse: Codable {
    let transactions: [TransactionListItemDto]
    let pagination: PaginationDto
}

struct TransactionListItemDto: Codable {
    let id: String
    let date: String
    let amountCents: Int64
    let signedAmountCents: Int64
    let currency: String
    let name: String
    let classification: String
    let account: AccountRefDto
    let category: CategoryRefDto?
    let merchant: MerchantRefDto?
    let location: TransactionLocationDto?
    let hasInvoicePhoto: Bool?
    let invoicePhoto: InvoicePhotoDto?
    let createdAt: String
    let updatedAt: String
}

// Approximate DEVICE location at the moment a bank notification was
// captured by the Android Wallet pipeline -- never the real merchant
// location, the notification itself never carries coordinates. iOS never
// captures this itself (no notification-listener API on the platform);
// this is read-only display of what Android already sent.
struct TransactionLocationDto: Codable {
    let latitude: Double
    let longitude: Double
    let device: String?
}

struct AccountRefDto: Codable {
    let id: String
    let name: String
    let accountType: String
}

struct CategoryRefDto: Codable {
    let id: String
    let name: String
    let color: String
    let icon: String
}

struct MerchantRefDto: Codable {
    let id: String
    let name: String
}

// MARK: - API Service

final class FinancePyApi {
    static let shared = FinancePyApi()
    private let client = ApiClient.shared

    private init() {}

    func fetchAllAccounts() async throws -> [AccountDto] {
        var allAccounts: [AccountDto] = []
        var page = 1
        var totalPages = 1

        repeat {
            let queryItems = [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "per_page", value: "100")
            ]
            let response: AccountsResponse = try await ApiClient.shared.request(path: "/api/v1/accounts", queryItems: queryItems)
            allAccounts.append(contentsOf: response.accounts)
            totalPages = response.pagination.totalPages
            page += 1
        } while page <= totalPages

        return allAccounts
    }

    func fetchBalanceSheet() async throws -> BalanceSheetResponse {
        return try await ApiClient.shared.request(path: "/api/v1/balance_sheet")
    }

    func fetchRecentTransactions(startDate: String) async throws -> [TransactionListItemDto] {
        var allTransactions: [TransactionListItemDto] = []
        var page = 1
        var totalPages = 1

        repeat {
            let queryItems = [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "per_page", value: "100"),
                URLQueryItem(name: "start_date", value: startDate)
            ]
            let response: TransactionsResponse = try await ApiClient.shared.request(path: "/api/v1/transactions", queryItems: queryItems)
            allTransactions.append(contentsOf: response.transactions)
            totalPages = response.pagination.totalPages
            page += 1
        } while page <= totalPages

        return allTransactions
    }

    /// Public, fail-open version check endpoint (Phase 5). Runs with a short
    /// 3-second timeout and no Authorization header so logged-out clients or
    /// clients with stale tokens still receive update prompts.
    func fetchAppConfig(currentBuild: Int, currentVersion: String) async throws -> AppConfigDto {
        guard var components = URLComponents(string: "\(ApiClient.shared.baseUrl)/api/v1/app_config") else {
            throw NetworkError.invalidUrl
        }
        components.queryItems = [
            URLQueryItem(name: "platform", value: "ios"),
            URLQueryItem(name: "build", value: String(currentBuild)),
            URLQueryItem(name: "version", value: currentVersion)
        ]
        guard let url = components.url else {
            throw NetworkError.invalidUrl
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 3.0
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("ios", forHTTPHeaderField: "X-Platform")
        request.setValue(currentVersion, forHTTPHeaderField: "X-App-Version")
        request.setValue(String(currentBuild), forHTTPHeaderField: "X-App-Build")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw NetworkError.invalidResponse
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(AppConfigDto.self, from: data)
    }
}

// MARK: - App Version Check (Phase 5)

struct AppConfigBuildDto: Codable {
    let android: Int?
    let ios: Int?
}

struct AppConfigDto: Codable {
    let minSupportedVersion: String
    let latestVersion: String
    let minBuild: AppConfigBuildDto?
    let latestBuild: AppConfigBuildDto?
    let androidStoreUrl: String?
    let iosStoreUrl: String?
    let directApkUrl: String?
    let forceUpdate: Bool
    let releaseNotes: String?
    let checkedAt: String?
}

enum AppUpdateState: Equatable {
    case upToDate
    case softUpdate(latestVersion: String, latestBuild: Int, releaseNotes: String?, updateUrl: URL?)
    case forceUpdate(minVersion: String, latestVersion: String, releaseNotes: String?, updateUrl: URL?)
}

enum AppUpdateEvaluator {
    static func evaluate(
        config: AppConfigDto,
        currentVersion: String,
        currentBuild: Int
    ) -> AppUpdateState {
        let minBuild = config.minBuild?.ios
        let latestBuild = config.latestBuild?.ios
        let safeUrl = validatedHttpsUrl(config.iosStoreUrl)

        let belowMinBuild = minBuild != nil && currentBuild < minBuild!
        let belowMinSemver = compareSemVer(currentVersion, config.minSupportedVersion) < 0

        if config.forceUpdate || belowMinBuild || belowMinSemver {
            return .forceUpdate(
                minVersion: config.minSupportedVersion,
                latestVersion: config.latestVersion,
                releaseNotes: config.releaseNotes,
                updateUrl: safeUrl
            )
        }

        let belowLatestBuild = latestBuild != nil && currentBuild < latestBuild!
        let belowLatestSemver = latestBuild == nil && compareSemVer(currentVersion, config.latestVersion) < 0

        if belowLatestBuild || belowLatestSemver {
            return .softUpdate(
                latestVersion: config.latestVersion,
                latestBuild: latestBuild ?? currentBuild,
                releaseNotes: config.releaseNotes,
                updateUrl: safeUrl
            )
        }

        return .upToDate
    }

    static func validatedHttpsUrl(_ raw: String?) -> URL? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              trimmed.lowercased().hasPrefix("https://"),
              let url = URL(string: trimmed),
              url.scheme?.lowercased() == "https",
              url.host != nil else {
            return nil
        }
        return url
    }

    static func compareSemVer(_ lhs: String, _ rhs: String) -> Int {
        let a = parseSemVer(lhs)
        let b = parseSemVer(rhs)
        for i in 0..<3 {
            if a[i] != b[i] {
                return a[i] < b[i] ? -1 : 1
            }
        }
        return 0
    }

    private static func parseSemVer(_ version: String) -> [Int] {
        let cleaned = version
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: "-").first.map(String.init) ?? version
        let parts = cleaned.split(separator: ".").map { Int($0) ?? 0 }
        return [
            parts.indices.contains(0) ? parts[0] : 0,
            parts.indices.contains(1) ? parts[1] : 0,
            parts.indices.contains(2) ? parts[2] : 0
        ]
    }
}
