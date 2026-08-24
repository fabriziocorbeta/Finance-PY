import Foundation
import SwiftData

@Model
final class TransactionEntity {
    @Attribute(.unique) var id: String
    var entryId: String
    var signedAmountCents: Int64
    var categoryId: String?
    var categoryName: String?
    var categoryColor: String?
    var categoryIcon: String?
    var merchantId: String?
    var merchantName: String?

    var entry: EntryEntity?

    init(
        id: String,
        entryId: String,
        signedAmountCents: Int64,
        categoryId: String? = nil,
        categoryName: String? = nil,
        categoryColor: String? = nil,
        categoryIcon: String? = nil,
        merchantId: String? = nil,
        merchantName: String? = nil,
        entry: EntryEntity? = nil
    ) {
        self.id = id
        self.entryId = entryId
        self.signedAmountCents = signedAmountCents
        self.categoryId = categoryId
        self.categoryName = categoryName
        self.categoryColor = categoryColor
        self.categoryIcon = categoryIcon
        self.merchantId = merchantId
        self.merchantName = merchantName
        self.entry = entry
    }
}
