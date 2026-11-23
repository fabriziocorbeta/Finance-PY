import SwiftUI

struct PurchaseOrderFormView: View {
    var poId: String? // If nil, we are creating

    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var supplierName = ""
    @State private var currency = "pyg"
    @State private var expectedDate = ""
    @State private var notes = ""
    @State private var items: [PurchaseOrderItemAttributes] = []

    @State private var hasRemoteInvoicePhoto = false
    @State private var remoteInvoiceFilename: String?
    @State private var invoicePhotoData: Data?
    @State private var pendingPhotoUpload: (data: Data, fileName: String)?
    @State private var isLoadingPhoto = false
    @State private var isUploadingPhoto = false

    var body: some View {
        Form {
            if let errorMessage = errorMessage {
                Section {
                    Text(errorMessage).foregroundColor(.red)
                }
            }

            Section("Detalles Generales") {
                TextField("Proveedor", text: $supplierName)
                TextField("Moneda", text: $currency)
                TextField("Fecha Esperada (YYYY-MM-DD)", text: $expectedDate)
                TextField("Notas", text: $notes)
            }

            Section("Productos") {
                ForEach($items, id: \.uniqueId) { $item in
                    VStack(alignment: .leading) {
                        TextField("ID Producto", text: $item.productId)
                        HStack {
                            Stepper("Cantidad: \(item.quantity)", value: $item.quantity, in: 1...1000)
                            Spacer()
                            TextField("Costo Unitario", value: $item.unitCost, format: .number)
                                .keyboardType(.decimalPad)
                        }
                    }
                }
                .onDelete { indexSet in
                    items.remove(atOffsets: indexSet)
                }

                Button("Agregar Producto") {
                    items.append(PurchaseOrderItemAttributes(productId: "", quantity: 1, unitCost: 0.0))
                }
            }

            Section("Foto de Factura") {
                InvoicePhotoSectionView(
                    title: "Factura adjunta",
                    hasRemotePhoto: hasRemoteInvoicePhoto,
                    remoteFilename: remoteInvoiceFilename,
                    imageData: invoicePhotoData,
                    isLoading: isLoadingPhoto,
                    isUploading: isUploadingPhoto,
                    onPickImage: { data, fileName in
                        invoicePhotoData = data
                        pendingPhotoUpload = (data, fileName)
                    },
                    onDeletePhoto: {
                        Task { await deleteInvoicePhoto() }
                    }
                )
            }
        }
        .navigationTitle(poId == nil ? "Nueva OC" : "Editar OC")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Guardar") {
                    Task { await savePurchaseOrder() }
                }
                .disabled(isLoading)
            }
        }
        .task {
            if let id = poId {
                await loadPurchaseOrder(id: id)
            }
        }
        .overlay {
            if isLoading {
                ProgressView()
                    .padding()
                    .background(Color(.systemBackground).opacity(0.8))
                    .cornerRadius(8)
            }
        }
    }

    private func loadPurchaseOrder(id: String) async {
        isLoading = true
        do {
            let po = try await FinancePyApi.shared.fetchPurchaseOrder(id: id)
            self.supplierName = po.supplierName ?? ""
            self.currency = po.currency
            self.expectedDate = po.expectedDate ?? ""
            self.notes = po.notes ?? ""
            if let poItems = po.purchaseOrderItems {
                self.items = poItems.map {
                    PurchaseOrderItemAttributes(id: $0.id, productId: $0.productId, quantity: $0.quantity, unitCost: $0.unitCost)
                }
            }
            self.hasRemoteInvoicePhoto = po.hasInvoicePhoto ?? false
            self.remoteInvoiceFilename = po.invoicePhoto?.filename
            if self.hasRemoteInvoicePhoto {
                isLoadingPhoto = true
                if let data = try? await FinancePyApi.shared.downloadPurchaseOrderInvoicePhoto(purchaseOrderId: id) {
                    invoicePhotoData = data
                }
                isLoadingPhoto = false
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func deleteInvoicePhoto() async {
        pendingPhotoUpload = nil
        invoicePhotoData = nil
        guard hasRemoteInvoicePhoto, let id = poId else {
            hasRemoteInvoicePhoto = false
            return
        }
        isUploadingPhoto = true
        defer { isUploadingPhoto = false }
        do {
            _ = try await FinancePyApi.shared.deletePurchaseOrderInvoicePhoto(purchaseOrderId: id)
            hasRemoteInvoicePhoto = false
            remoteInvoiceFilename = nil
        } catch {
            if NetworkMonitor.isConnectivityError(error) {
                OfflineOutbox.shared.enqueue(.deleteInvoicePhoto(entityType: .purchaseOrder, entityId: id))
                hasRemoteInvoicePhoto = false
                remoteInvoiceFilename = nil
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func savePurchaseOrder() async {
        isLoading = true
        let payload = PurchaseOrderDataPayload(
            supplierName: supplierName,
            currency: currency,
            expectedDate: expectedDate.isEmpty ? nil : expectedDate,
            notes: notes,
            accountId: nil,
            purchaseOrderItemsAttributes: items
        )

        do {
            let saved: PurchaseOrderDto
            if let id = poId {
                saved = try await FinancePyApi.shared.updatePurchaseOrder(id: id, payload: payload)
            } else {
                saved = try await FinancePyApi.shared.createPurchaseOrder(payload: payload)
            }
            if let pending = pendingPhotoUpload {
                isUploadingPhoto = true
                do {
                    _ = try await FinancePyApi.shared.uploadPurchaseOrderInvoicePhoto(
                        purchaseOrderId: saved.id,
                        fileData: pending.data,
                        fileName: pending.fileName
                    )
                } catch {
                    if NetworkMonitor.isConnectivityError(error) {
                        let blobId = OfflineBlobStore.shared.saveBlob(pending.data)
                        OfflineOutbox.shared.enqueue(.uploadInvoicePhoto(entityType: .purchaseOrder, entityId: saved.id, blobId: blobId, fileName: pending.fileName, mimeType: "image/jpeg"))
                    }
                }
                isUploadingPhoto = false
            }
            dismiss()
        } catch {
            if NetworkMonitor.isConnectivityError(error) {
                if let id = poId {
                    OfflineOutbox.shared.enqueue(.updatePurchaseOrder(id: id, payload: payload))
                    if let pending = pendingPhotoUpload {
                        let blobId = OfflineBlobStore.shared.saveBlob(pending.data)
                        OfflineOutbox.shared.enqueue(.uploadInvoicePhoto(entityType: .purchaseOrder, entityId: id, blobId: blobId, fileName: pending.fileName, mimeType: "image/jpeg"))
                    }
                } else {
                    OfflineOutbox.shared.enqueue(.createPurchaseOrder(payload))
                }
                dismiss()
                return
            }
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
