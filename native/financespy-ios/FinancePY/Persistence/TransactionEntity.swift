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
    // Approximate DEVICE location at Wallet-capture time (Android-only
    // capture, see TransactionLocationDto) -- never the real merchant
    // location. nil for any transaction not captured that way.
    var latitude: Double?
    var longitude: Double?
    var device: String?

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
        latitude: Double? = nil,
        longitude: Double? = nil,
        device: String? = nil,
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
        self.latitude = latitude
        self.longitude = longitude
        self.device = device
        self.entry = entry
    }
}
