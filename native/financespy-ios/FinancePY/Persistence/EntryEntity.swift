import Foundation
import SwiftData

@Model
final class EntryEntity {
    @Attribute(.unique) var id: String
    var accountId: String
    var date: String
    var name: String
    var amountCents: Int64
    var currency: String
    var classification: String
    var createdAt: String
    var updatedAt: String

    @Relationship(deleteRule: .cascade, inverse: \TransactionEntity.entry)
    var transaction: TransactionEntity?

    init(
        id: String,
        accountId: String,
        date: String,
        name: String,
        amountCents: Int64,
        currency: String,
        classification: String,
        createdAt: String,
        updatedAt: String,
        transaction: TransactionEntity? = nil
    ) {
        self.id = id
        self.accountId = accountId
        self.date = date
        self.name = name
        self.amountCents = amountCents
        self.currency = currency
        self.classification = classification
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.transaction = transaction
    }
}
