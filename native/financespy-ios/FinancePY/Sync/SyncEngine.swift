import Foundation
import SwiftData

@MainActor
final class SyncEngine: ObservableObject {
    private let api = FinancePyApi.shared
    private let modelContext: ModelContext

    @Published var isSyncing = false
    @Published var lastSyncError: String?
    @Published var balanceSheet: BalanceSheetResponse?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func syncAll() async -> Result<Void, Error> {
        isSyncing = true
        lastSyncError = nil

        do {
            try await syncAccounts()
            try await syncBalanceSheet()
            try await syncTransactions()
            try await syncReceivables()
            try modelContext.save()
            isSyncing = false
            return .success(())
        } catch {
            isSyncing = false
            lastSyncError = error.localizedDescription
            return .failure(error)
        }
    }

    private func syncAccounts() async throws {
        let remoteAccounts = try await api.fetchAllAccounts()
        let remoteIds = Set(remoteAccounts.map { $0.id })

        // Fetch existing local accounts
        let descriptor = FetchDescriptor<AccountEntity>()
        let localAccounts = try modelContext.fetch(descriptor)
        let localDict = Dictionary(uniqueKeysWithValues: localAccounts.map { ($0.id, $0) })

        // Upsert remote accounts
        for dto in remoteAccounts {
            if let existing = localDict[dto.id] {
                existing.name = dto.name
                existing.balanceCents = dto.balanceCents
                existing.cashBalanceCents = dto.cashBalanceCents
                existing.currency = dto.currency
                existing.classification = dto.classification
                existing.accountType = dto.accountType
                existing.subtype = dto.subtype
                existing.status = dto.status
                existing.updatedAt = dto.updatedAt
            } else {
                let newEntity = AccountEntity(
                    id: dto.id,
                    name: dto.name,
                    balanceCents: dto.balanceCents,
                    cashBalanceCents: dto.cashBalanceCents,
                    currency: dto.currency,
                    classification: dto.classification,
                    accountType: dto.accountType,
                    subtype: dto.subtype,
                    status: dto.status,
                    updatedAt: dto.updatedAt
                )
                modelContext.insert(newEntity)
            }
        }

        // Delete accounts no longer present remotely
        for local in localAccounts {
            if !remoteIds.contains(local.id) {
                modelContext.delete(local)
            }
        }
    }

    private func syncBalanceSheet() async throws {
        let bs = try await api.fetchBalanceSheet()
        self.balanceSheet = bs
    }

    private func syncTransactions() async throws {
        let calendar = Calendar.current
        let ninetyDaysAgo = calendar.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let startDateString = formatter.string(from: ninetyDaysAgo)

        let remoteTransactions = try await api.fetchRecentTransactions(startDate: startDateString)
        let remoteIds = Set(remoteTransactions.map { $0.id })

        // Fetch existing entries in the 90-day window
        let descriptor = FetchDescriptor<EntryEntity>(
            predicate: #Predicate<EntryEntity> { entry in
                entry.date >= startDateString
            }
        )
        let localEntries = try modelContext.fetch(descriptor)
        let localDict = Dictionary(uniqueKeysWithValues: localEntries.map { ($0.id, $0) })

        // Upsert remote entries & transaction details
        for dto in remoteTransactions {
            let categoryName = dto.category?.name
            let categoryColor = dto.category?.color
            let categoryIcon = dto.category?.icon
            let merchantName = dto.merchant?.name

            if let existingEntry = localDict[dto.id] {
                existingEntry.accountId = dto.account.id
                existingEntry.date = dto.date
                existingEntry.name = dto.name
                existingEntry.amountCents = dto.amountCents
                existingEntry.currency = dto.currency
                existingEntry.classification = dto.classification
                existingEntry.createdAt = dto.createdAt
                existingEntry.updatedAt = dto.updatedAt

                if let existingTx = existingEntry.transaction {
                    existingTx.signedAmountCents = dto.signedAmountCents
                    existingTx.categoryId = dto.category?.id
                    existingTx.categoryName = categoryName
                    existingTx.categoryColor = categoryColor
                    existingTx.categoryIcon = categoryIcon
                    existingTx.merchantId = dto.merchant?.id
                    existingTx.merchantName = merchantName
                } else {
                    let txEntity = TransactionEntity(
                        id: dto.id,
                        entryId: dto.id,
                        signedAmountCents: dto.signedAmountCents,
                        categoryId: dto.category?.id,
                        categoryName: categoryName,
                        categoryColor: categoryColor,
                        categoryIcon: categoryIcon,
                        merchantId: dto.merchant?.id,
                        merchantName: merchantName,
                        entry: existingEntry
                    )
                    existingEntry.transaction = txEntity
                    modelContext.insert(txEntity)
                }
            } else {
                let txEntity = TransactionEntity(
                    id: dto.id,
                    entryId: dto.id,
                    signedAmountCents: dto.signedAmountCents,
                    categoryId: dto.category?.id,
                    categoryName: categoryName,
                    categoryColor: categoryColor,
                    categoryIcon: categoryIcon,
                    merchantId: dto.merchant?.id,
                    merchantName: merchantName
                )

                let entryEntity = EntryEntity(
                    id: dto.id,
                    accountId: dto.account.id,
                    date: dto.date,
                    name: dto.name,
                    amountCents: dto.amountCents,
                    currency: dto.currency,
                    classification: dto.classification,
                    createdAt: dto.createdAt,
                    updatedAt: dto.updatedAt,
                    transaction: txEntity
                )
                txEntity.entry = entryEntity

                modelContext.insert(entryEntity)
                modelContext.insert(txEntity)
            }
        }

        // Remove local entries in the 90-day window that are no longer present remotely
        for local in localEntries {
            if !remoteIds.contains(local.id) {
                if let tx = local.transaction {
                    modelContext.delete(tx)
                }
                modelContext.delete(local)
            }
        }
    }

    private func syncReceivables() async throws {
        let remoteReceivables = try await api.fetchReceivables()
        let remoteIds = Set(remoteReceivables.map { $0.id })

        let descriptor = FetchDescriptor<ReceivableEntity>()
        let localReceivables = try modelContext.fetch(descriptor)
        let localDict = Dictionary(uniqueKeysWithValues: localReceivables.map { ($0.id, $0) })

        for dto in remoteReceivables {
            let installmentScheduleData: Data? = {
                if let schedule = dto.installmentSchedule {
                    let encoder = JSONEncoder()
                    encoder.keyEncodingStrategy = .convertToSnakeCase
                    return try? encoder.encode(schedule)
                }
                return nil
            }()

            if let existing = localDict[dto.id] {
                existing.accountId = dto.accountId
                existing.name = dto.name ?? "(sin nombre)"
                existing.totalAmount = dto.totalAmount ?? 0.0
                existing.balance = dto.balance ?? 0.0
                existing.balanceCents = dto.balanceCents ?? 0
                existing.originalBalance = dto.originalBalance ?? 0.0
                existing.originalBalanceCents = dto.originalBalanceCents ?? 0
                existing.paidAmount = dto.paidAmount ?? 0.0
                existing.paidAmountCents = dto.paidAmountCents ?? 0
                existing.percentPaid = dto.percentPaid ?? 0.0
                existing.installmentCount = dto.installmentCount
                existing.dueDay = dto.dueDay
                existing.currency = dto.currency ?? "PYG"
                existing.notes = dto.notes
                existing.updatedAt = dto.updatedAt ?? ""
                existing.installmentScheduleData = installmentScheduleData
            } else {
                let newEntity = ReceivableEntity(
                    id: dto.id,
                    accountId: dto.accountId,
                    name: dto.name ?? "(sin nombre)",
                    totalAmount: dto.totalAmount ?? 0.0,
                    balance: dto.balance ?? 0.0,
                    balanceCents: dto.balanceCents ?? 0,
                    originalBalance: dto.originalBalance ?? 0.0,
                    originalBalanceCents: dto.originalBalanceCents ?? 0,
                    paidAmount: dto.paidAmount ?? 0.0,
                    paidAmountCents: dto.paidAmountCents ?? 0,
                    percentPaid: dto.percentPaid ?? 0.0,
                    installmentCount: dto.installmentCount,
                    dueDay: dto.dueDay,
                    currency: dto.currency ?? "PYG",
                    notes: dto.notes,
                    updatedAt: dto.updatedAt ?? "",
                    installmentScheduleData: installmentScheduleData
                )
                modelContext.insert(newEntity)
            }
        }

        // Delete receivables no longer present remotely
        for local in localReceivables {
            if !remoteIds.contains(local.id) {
                modelContext.delete(local)
            }
        }
    }
}
