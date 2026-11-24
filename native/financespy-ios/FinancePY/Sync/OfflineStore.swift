import Foundation
import Network
import SwiftUI

// MARK: - Network Monitor

@MainActor
final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    @Published private(set) var isConnected: Bool = true
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "py.com.cdco.financespy.network-monitor")

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            Task { @MainActor [weak self] in
                guard let self else { return }
                let wasOffline = !self.isConnected
                self.isConnected = connected
                if wasOffline && connected {
                    await OfflineOutbox.shared.flush()
                }
            }
        }
        monitor.start(queue: queue)
    }

    static func isConnectivityError(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            let offlineCodes: Set<URLError.Code> = [
                .notConnectedToInternet, .networkConnectionLost, .timedOut,
                .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed,
                .dataNotAllowed, .internationalRoamingOff
            ]
            return offlineCodes.contains(urlError.code)
        }
        return false
    }
}

// MARK: - Offline Disk JSON Cache

final class OfflineCache {
    static let shared = OfflineCache()

    private let fileManager = FileManager.default
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    private var cacheDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        var dir = appSupport.appendingPathComponent("FinancePYOfflineCache", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try? dir.setResourceValues(values)
        }
        return dir
    }

    private func fileURL(for key: String) -> URL {
        let safeKey = key.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        return cacheDirectory.appendingPathComponent("\(safeKey).json")
    }

    func save<T: Encodable>(_ value: T, key: String) {
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: fileURL(for: key), options: [.atomic, .completeFileProtection])
    }

    func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        let url = fileURL(for: key)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(type, from: data)
    }

    func remove(key: String) {
        try? fileManager.removeItem(at: fileURL(for: key))
    }

    func clearAll() {
        try? fileManager.removeItem(at: cacheDirectory)
    }
}

// MARK: - Offline Disk Blob Store

final class OfflineBlobStore {
    static let shared = OfflineBlobStore()

    private let fileManager = FileManager.default

    private var blobsDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        var dir = appSupport.appendingPathComponent("FinancePYOfflineBlobs", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try? dir.setResourceValues(values)
        }
        return dir
    }

    @discardableResult
    func saveBlob(_ data: Data, id: String = UUID().uuidString) -> String {
        let url = blobsDirectory.appendingPathComponent(id)
        try? data.write(to: url, options: [.atomic, .completeFileProtection])
        return id
    }

    func loadBlob(id: String) -> Data? {
        let url = blobsDirectory.appendingPathComponent(id)
        return try? Data(contentsOf: url)
    }

    func deleteBlob(id: String) {
        let url = blobsDirectory.appendingPathComponent(id)
        try? fileManager.removeItem(at: url)
    }

    func clearAll() {
        try? fileManager.removeItem(at: blobsDirectory)
    }
}

// MARK: - Offline Outbox

enum OutboxEntityType: String, Codable {
    case transaction
    case sale
    case purchaseOrder
}

enum OutboxOperationKind: Codable {
    case createTransaction(CreateTransactionBody)
    case updateTransaction(id: String, body: UpdateTransactionBody)
    case deleteTransaction(id: String)

    case createSale(SaleDataPayload)
    case updateSale(id: String, payload: SaleDataPayload)
    case completeSale(id: String)
    case cancelSale(id: String)
    case deleteSale(id: String)

    case createPurchaseOrder(PurchaseOrderDataPayload)
    case updatePurchaseOrder(id: String, payload: PurchaseOrderDataPayload)
    case receivePurchaseOrder(id: String)
    case cancelPurchaseOrder(id: String)
    case deletePurchaseOrder(id: String)

    case uploadInvoicePhoto(entityType: OutboxEntityType, entityId: String, blobId: String, fileName: String, mimeType: String)
    case deleteInvoicePhoto(entityType: OutboxEntityType, entityId: String)
}

struct OutboxOperation: Codable, Identifiable {
    let id: String
    let createdAt: Date
    let kind: OutboxOperationKind
    var retryCount: Int = 0
    var lastError: String? = nil

    init(kind: OutboxOperationKind) {
        self.id = UUID().uuidString
        self.createdAt = Date()
        self.kind = kind
    }
}

@MainActor
final class OfflineOutbox: ObservableObject {
    static let shared = OfflineOutbox()

    private let cacheKey = "offline_outbox_operations"
    @Published private(set) var pendingOperations: [OutboxOperation] = []
    @Published private(set) var isFlushing: Bool = false

    private init() {
        pendingOperations = OfflineCache.shared.load([OutboxOperation].self, key: cacheKey) ?? []
    }

    var pendingCount: Int { pendingOperations.count }

    func enqueue(_ kind: OutboxOperationKind) {
        pendingOperations.append(OutboxOperation(kind: kind))
        persist()
    }

    func clearAll() {
        for op in pendingOperations {
            if case .uploadInvoicePhoto(_, _, let blobId, _, _) = op.kind {
                OfflineBlobStore.shared.deleteBlob(id: blobId)
            }
        }
        pendingOperations = []
        OfflineCache.shared.remove(key: cacheKey)
    }

    func flush() async {
        guard !isFlushing, !pendingOperations.isEmpty, NetworkMonitor.shared.isConnected else { return }
        isFlushing = true
        defer { isFlushing = false }

        var remaining: [OutboxOperation] = []
        var stopDueToOffline = false

        for var op in pendingOperations {
            if stopDueToOffline {
                remaining.append(op)
                continue
            }

            do {
                try await execute(op.kind)
                if case .uploadInvoicePhoto(_, _, let blobId, _, _) = op.kind {
                    OfflineBlobStore.shared.deleteBlob(id: blobId)
                }
            } catch {
                if NetworkMonitor.isConnectivityError(error) {
                    stopDueToOffline = true
                    remaining.append(op)
                } else {
                    op.retryCount += 1
                    op.lastError = UserFacingError.message(for: error)
                    if op.retryCount < 5 {
                        remaining.append(op)
                    } else if case .uploadInvoicePhoto(_, _, let blobId, _, _) = op.kind {
                        OfflineBlobStore.shared.deleteBlob(id: blobId)
                    }
                }
            }
        }

        pendingOperations = remaining
        persist()
    }

    private func execute(_ kind: OutboxOperationKind) async throws {
        let api = FinancePyApi.shared
        switch kind {
        case .createTransaction(let body):
            _ = try await api.createTransaction(body: body)
        case .updateTransaction(let id, let body):
            _ = try await api.updateTransaction(id: id, body: body)
        case .deleteTransaction(let id):
            _ = try await api.deleteTransaction(id: id)

        case .createSale(let payload):
            _ = try await api.createSale(payload: payload)
        case .updateSale(let id, let payload):
            _ = try await api.updateSale(id: id, payload: payload)
        case .completeSale(let id):
            _ = try await api.completeSale(id: id)
        case .cancelSale(let id):
            _ = try await api.cancelSale(id: id)
        case .deleteSale(let id):
            try await api.deleteSale(id: id)

        case .createPurchaseOrder(let payload):
            _ = try await api.createPurchaseOrder(payload: payload)
        case .updatePurchaseOrder(let id, let payload):
            _ = try await api.updatePurchaseOrder(id: id, payload: payload)
        case .receivePurchaseOrder(let id):
            _ = try await api.receivePurchaseOrder(id: id)
        case .cancelPurchaseOrder(let id):
            _ = try await api.cancelPurchaseOrder(id: id)
        case .deletePurchaseOrder(let id):
            try await api.deletePurchaseOrder(id: id)

        case .uploadInvoicePhoto(let entityType, let entityId, let blobId, let fileName, let mimeType):
            guard let data = OfflineBlobStore.shared.loadBlob(id: blobId) else { return }
            switch entityType {
            case .transaction:
                _ = try await api.uploadTransactionInvoicePhoto(transactionId: entityId, fileData: data, fileName: fileName, mimeType: mimeType)
            case .sale:
                _ = try await api.uploadSaleInvoicePhoto(saleId: entityId, fileData: data, fileName: fileName, mimeType: mimeType)
            case .purchaseOrder:
                _ = try await api.uploadPurchaseOrderInvoicePhoto(purchaseOrderId: entityId, fileData: data, fileName: fileName, mimeType: mimeType)
            }

        case .deleteInvoicePhoto(let entityType, let entityId):
            switch entityType {
            case .transaction:
                _ = try await api.deleteTransactionInvoicePhoto(transactionId: entityId)
            case .sale:
                _ = try await api.deleteSaleInvoicePhoto(saleId: entityId)
            case .purchaseOrder:
                _ = try await api.deletePurchaseOrderInvoicePhoto(purchaseOrderId: entityId)
            }
        }
    }

    private func persist() {
        OfflineCache.shared.save(pendingOperations, key: cacheKey)
    }
}

// MARK: - Offline Banner View

struct OfflineBannerView: View {
    @ObservedObject var networkMonitor = NetworkMonitor.shared
    @ObservedObject var outbox = OfflineOutbox.shared

    var body: some View {
        if !networkMonitor.isConnected || outbox.pendingCount > 0 {
            HStack(spacing: 10) {
                Image(systemName: networkMonitor.isConnected ? "arrow.triangle.2.circlepath" : "wifi.slash")
                    .font(.subheadline.weight(.semibold))

                VStack(alignment: .leading, spacing: 2) {
                    if !networkMonitor.isConnected {
                        Text("Modo sin conexión")
                            .font(.caption.weight(.semibold))
                        Text(outbox.pendingCount > 0
                             ? "\(outbox.pendingCount) cambio(s) pendiente(s) de sincronizar"
                             : "Mostrando datos guardados localmente")
                            .font(.caption2)
                            .opacity(0.9)
                    } else {
                        Text("\(outbox.pendingCount) cambio(s) pendiente(s)")
                            .font(.caption.weight(.semibold))
                    }
                }

                Spacer()

                if networkMonitor.isConnected && outbox.pendingCount > 0 {
                    if outbox.isFlushing {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                    } else {
                        Button("Sincronizar") {
                            Task { await outbox.flush() }
                        }
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Capsule())
                    }
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(networkMonitor.isConnected ? Color.blue : Color.orange)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}
