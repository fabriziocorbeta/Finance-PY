import SwiftUI

struct SaleFormView: View {
    var saleId: String? // If nil, we are creating

    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var clientName = ""
    @State private var currency = "pyg"
    @State private var notes = ""
    @State private var items: [SaleItemAttributes] = []

    @State private var hasRemoteInvoicePhoto = false
    @State private var remoteInvoiceFilename: String?
    @State private var invoicePhotoData: Data?
    @State private var pendingPhotoUpload: (data: Data, fileName: String)?
    @State private var isLoadingPhoto = false
    @State private var isUploadingPhoto = false

    // We should probably allow selecting products, but a simple text field for productId for now
    // or a simplified implementation since this is mainly mirroring what KMP has.
    // In KMP, there's a product picker. We'll add a minimal product input for now.

    var body: some View {
        Form {
            if let errorMessage = errorMessage {
                Section {
                    Text(errorMessage).foregroundColor(.red)
                }
            }

            Section("Detalles Generales") {
                TextField("Cliente", text: $clientName)
                TextField("Moneda", text: $currency)
                TextField("Notas", text: $notes)
            }

            Section("Productos") {
                ForEach($items, id: \.uniqueId) { $item in
                    VStack(alignment: .leading) {
                        TextField("ID Producto", text: $item.productId)
                        HStack {
                            Stepper("Cantidad: \(item.quantity)", value: $item.quantity, in: 1...1000)
                            Spacer()
                            TextField("Precio Unitario", value: $item.unitPrice, format: .number)
                                .keyboardType(.decimalPad)
                        }
                    }
                }
                .onDelete { indexSet in
                    items.remove(atOffsets: indexSet)
                }

                Button("Agregar Producto") {
                    items.append(SaleItemAttributes(productId: "", quantity: 1, unitPrice: 0.0))
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
        .navigationTitle(saleId == nil ? "Nueva Venta" : "Editar Venta")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Guardar") {
                    Task { await saveSale() }
                }
                .disabled(isLoading)
            }
        }
        .task {
            if let id = saleId {
                await loadSale(id: id)
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

    private func loadSale(id: String) async {
        isLoading = true
        do {
            let sale = try await FinancePyApi.shared.fetchSale(id: id)
            self.clientName = sale.clientName ?? ""
            self.currency = sale.currency
            self.notes = sale.notes ?? ""
            if let saleItems = sale.saleItems {
                self.items = saleItems.map {
                    SaleItemAttributes(id: $0.id, productId: $0.productId, quantity: $0.quantity, unitPrice: $0.unitPrice)
                }
            }
            self.hasRemoteInvoicePhoto = sale.hasInvoicePhoto ?? false
            self.remoteInvoiceFilename = sale.invoicePhoto?.filename
            if self.hasRemoteInvoicePhoto {
                isLoadingPhoto = true
                if let data = try? await FinancePyApi.shared.downloadSaleInvoicePhoto(saleId: id) {
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
        guard hasRemoteInvoicePhoto, let id = saleId else {
            hasRemoteInvoicePhoto = false
            return
        }
        isUploadingPhoto = true
        defer { isUploadingPhoto = false }
        do {
            _ = try await FinancePyApi.shared.deleteSaleInvoicePhoto(saleId: id)
            hasRemoteInvoicePhoto = false
            remoteInvoiceFilename = nil
        } catch {
            if NetworkMonitor.isConnectivityError(error) {
                OfflineOutbox.shared.enqueue(.deleteInvoicePhoto(entityType: .sale, entityId: id))
                hasRemoteInvoicePhoto = false
                remoteInvoiceFilename = nil
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func saveSale() async {
        isLoading = true
        let payload = SaleDataPayload(
            clientName: clientName,
            currency: currency,
            notes: notes,
            accountId: nil,
            saleItemsAttributes: items
        )

        do {
            let saved: SaleDto
            if let id = saleId {
                saved = try await FinancePyApi.shared.updateSale(id: id, payload: payload)
            } else {
                saved = try await FinancePyApi.shared.createSale(payload: payload)
            }
            if let pending = pendingPhotoUpload {
                isUploadingPhoto = true
                do {
                    _ = try await FinancePyApi.shared.uploadSaleInvoicePhoto(
                        saleId: saved.id,
                        fileData: pending.data,
                        fileName: pending.fileName
                    )
                } catch {
                    if NetworkMonitor.isConnectivityError(error) {
                        let blobId = OfflineBlobStore.shared.saveBlob(pending.data)
                        OfflineOutbox.shared.enqueue(.uploadInvoicePhoto(entityType: .sale, entityId: saved.id, blobId: blobId, fileName: pending.fileName, mimeType: "image/jpeg"))
                    }
                }
                isUploadingPhoto = false
            }
            dismiss()
        } catch {
            if NetworkMonitor.isConnectivityError(error) {
                if let id = saleId {
                    OfflineOutbox.shared.enqueue(.updateSale(id: id, payload: payload))
                    if let pending = pendingPhotoUpload {
                        let blobId = OfflineBlobStore.shared.saveBlob(pending.data)
                        OfflineOutbox.shared.enqueue(.uploadInvoicePhoto(entityType: .sale, entityId: id, blobId: blobId, fileName: pending.fileName, mimeType: "image/jpeg"))
                    }
                } else {
                    OfflineOutbox.shared.enqueue(.createSale(payload))
                }
                dismiss()
                return
            }
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
