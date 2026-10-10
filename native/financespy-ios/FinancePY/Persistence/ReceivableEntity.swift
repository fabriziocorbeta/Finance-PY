import Foundation
import SwiftData

@Model
final class ReceivableEntity {
    @Attribute(.unique) var id: String
    var accountId: String?
    var name: String
    var totalAmount: Double
    var balance: Double
    var balanceCents: Int64
    var originalBalance: Double
    var originalBalanceCents: Int64
    var paidAmount: Double
    var paidAmountCents: Int64
    var percentPaid: Double
    var installmentCount: Int?
    var dueDay: Int?
    var currency: String
    var notes: String?
    var updatedAt: String

    // JSON serialized installment schedule since SwiftData doesn't support complex arrays natively easily.
    var installmentScheduleData: Data?

    init(
        id: String,
        accountId: String?,
        name: String,
        totalAmount: Double,
        balance: Double,
        balanceCents: Int64,
        originalBalance: Double,
        originalBalanceCents: Int64,
        paidAmount: Double,
        paidAmountCents: Int64,
        percentPaid: Double,
        installmentCount: Int?,
        dueDay: Int?,
        currency: String,
        notes: String?,
        updatedAt: String,
        installmentScheduleData: Data?
    ) {
        self.id = id
        self.accountId = accountId
        self.name = name
        self.totalAmount = totalAmount
        self.balance = balance
        self.balanceCents = balanceCents
        self.originalBalance = originalBalance
        self.originalBalanceCents = originalBalanceCents
        self.paidAmount = paidAmount
        self.paidAmountCents = paidAmountCents
        self.percentPaid = percentPaid
        self.installmentCount = installmentCount
        self.dueDay = dueDay
        self.currency = currency
        self.notes = notes
        self.updatedAt = updatedAt
        self.installmentScheduleData = installmentScheduleData
    }

    var installmentSchedule: [InstallmentDto]? {
        get {
            guard let data = installmentScheduleData else { return nil }
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try? decoder.decode([InstallmentDto].self, from: data)
        }
        set {
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            installmentScheduleData = try? encoder.encode(newValue)
        }
    }
}
