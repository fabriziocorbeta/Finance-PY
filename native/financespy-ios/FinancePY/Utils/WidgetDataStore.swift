import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

struct WidgetExpenseItem: Codable, Identifiable {
    let id: String
    let name: String
    let date: String
    let amountCents: Int64
    let currency: String
    let categoryName: String?
}

struct WidgetSnapshot: Codable {
    let currency: String
    let liquidAvailableCents: Int64
    let netWorthCents: Int64
    let assetsCents: Int64
    let liabilitiesCents: Int64
    let monthlyExpensesCents: Int64
    let recentExpenses: [WidgetExpenseItem]
    let updatedAt: Date
}

final class WidgetDataStore {
    static let shared = WidgetDataStore()
    static let appGroupIdentifier = "group.py.com.cdco.financespy.ios"
    private let snapshotKey = "financepy_widget_snapshot_v1"

    private var defaults: UserDefaults {
        UserDefaults(suiteName: Self.appGroupIdentifier) ?? .standard
    }

    func saveSnapshot(_ snapshot: WidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: snapshotKey)
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    func loadSnapshot() -> WidgetSnapshot? {
        guard let data = defaults.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    func clear() {
        defaults.removeObject(forKey: snapshotKey)
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    static func computeLiquidAvailableCents(from accounts: [AccountDto], targetCurrency: String? = nil) -> Int64 {
        let liquidTypes: Set<String> = ["depository", "cash", "checking", "savings"]
        let resolvedCurrency = targetCurrency?.uppercased()
            ?? accounts.first(where: { $0.classification.lowercased() == "asset" })?.currency.uppercased()
        return accounts
            .filter { $0.classification.lowercased() == "asset" }
            .filter { account in
                // Never sum raw minor units across different currencies (e.g. PYG + USD).
                guard let resolvedCurrency else { return true }
                return account.currency.uppercased() == resolvedCurrency
            }
            .filter { account in
                liquidTypes.contains(account.accountType.lowercased())
                    || (account.subtype.map { liquidTypes.contains($0.lowercased()) } ?? false)
            }
            .reduce(Int64(0)) { $0 + $1.balanceCents }
    }
}
