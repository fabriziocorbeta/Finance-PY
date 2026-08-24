import Foundation
import SwiftData

@Model
final class AccountEntity {
    @Attribute(.unique) var id: String
    var name: String
    var balanceCents: Int64
    var cashBalanceCents: Int64
    var currency: String
    var classification: String
    var accountType: String
    var subtype: String?
    var status: String
    var updatedAt: String

    init(
        id: String,
        name: String,
        balanceCents: Int64,
        cashBalanceCents: Int64,
        currency: String,
        classification: String,
        accountType: String,
        subtype: String? = nil,
        status: String,
        updatedAt: String
    ) {
        self.id = id
        self.name = name
        self.balanceCents = balanceCents
        self.cashBalanceCents = cashBalanceCents
        self.currency = currency
        self.classification = classification
        self.accountType = accountType
        self.subtype = subtype
        self.status = status
        self.updatedAt = updatedAt
    }
}
