import SwiftUI

struct PurchaseOrderDetailView: View {
    let poId: String
    @Environment(\.dismiss) private var dismiss

    @State private var po: PurchaseOrderDto?
    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var showReceiveAlert = false
    @State private var showCancelAlert = false

    @State private var invoicePhotoData: Data?
    @State private var isLoadingPhoto = false
    @State private var isUploadingPhoto = false

    var body: some View {
        Group {
            if isLoading && po == nil {
                ProgressView()
            } else if let errorMessage = errorMessage {
                Text("Error: \(errorMessage)").foregroundColor(.red)
            } else if let po = po {
                List {
                    Section("Información General") {
                        LabeledContent("Estado", value: Formatters.purchaseOrderStatusLabel(po.status))
                        if let supplierName = po.supplierName {
                            LabeledContent("Proveedor", value: supplierName)
                        }
                        LabeledContent("Total", value: money(po.total, po.currency))
                        if let expectedDate = po.expectedDate {
                            LabeledContent("Fecha Esperada", value: Formatters.formatDate(expectedDate))
                        }
                        if let notes = po.notes {
                            LabeledContent("Notas", value: notes)
                        }
                    }

                    if let items = po.purchaseOrderItems, !items.isEmpty {
                        Section("Productos") {
                            ForEach(items, id: \.self) { item in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(item.productName ?? "Producto")
                                        Text("\(item.quantity) x \(money(item.unitCost, po.currency))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    if let sub = item.subtotal {
                                        Text(money(sub, po.currency))
                                    }
                                }
                            }
                        }
                    }

                    Section("Foto de Factura") {
                        InvoicePhotoSectionView(
                            title: "Factura adjunta",
                            hasRemotePhoto: po.hasInvoicePhoto ?? false,
                            remoteFilename: po.invoicePhoto?.filename,
                            imageData: invoicePhotoData,
                            isLoading: isLoadingPhoto,
                            isUploading: isUploadingPhoto,
                            onPickImage: { data, fileName in
                                Task { await uploadInvoicePhoto(data: data, fileName: fileName) }
                            },
                            onDeletePhoto: {
                                Task { await deleteInvoicePhoto() }
                            }
                        )
                    }

                    Section("Acciones") {
                        if po.status == "draft" {
                            Button("Recibir Orden") {
                                showReceiveAlert = true
                            }
                            .foregroundColor(.blue)

                            Button("Cancelar Orden") {
                                showCancelAlert = true
                            }
                            .foregroundColor(.red)
                        } else if po.status == "received" {
                            Button("Cancelar Orden") {
                                showCancelAlert = true
                            }
                            .foregroundColor(.red)
                        }
                    }
                }
                .navigationTitle("Detalle de OC")
                .toolbar {
                    if po.status == "draft" {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            NavigationLink("Editar", destination: PurchaseOrderFormView(poId: po.id))
                        }
                    }
                }
            }
        }
        .task {
            await fetchPurchaseOrder()
        }
        .alert("Recibir Orden", isPresented: $showReceiveAlert) {
            Button("Cancelar", role: .cancel) { }
            Button("Recibir", role: .destructive) {
                Task { await receivePurchaseOrder() }
            }
        } message: {
            Text("¿Estás seguro de que deseas recibir esta orden? Se agregará al stock.")
        }
        .alert("Cancelar Orden", isPresented: $showCancelAlert) {
            Button("Volver", role: .cancel) { }
            Button("Confirmar Cancelación", role: .destructive) {
                Task { await cancelPurchaseOrder() }
            }
        } message: {
            Text("¿Estás seguro de que deseas cancelar esta orden?")
        }
    }

    private func fetchPurchaseOrder() async {
        isLoading = true
        if po == nil {
            po = OfflineCache.shared.load(PurchaseOrderDto.self, key: "purchase_order_\(poId)")
        }
        do {
            let fetched = try await FinancePyApi.shared.fetchPurchaseOrder(id: poId)
            po = fetched
            OfflineCache.shared.save(fetched, key: "purchase_order_\(poId)")
            if fetched.hasInvoicePhoto == true {
                await loadInvoicePhoto()
            }
        } catch {
            if po == nil {
                errorMessage = error.localizedDescription
            }
        }
        isLoading = false
    }

    private func loadInvoicePhoto() async {
        isLoadingPhoto = true
        defer { isLoadingPhoto = false }
        if let data = try? await FinancePyApi.shared.downloadPurchaseOrderInvoicePhoto(purchaseOrderId: poId) {
            invoicePhotoData = data
        }
    }

    private func uploadInvoicePhoto(data: Data, fileName: String) async {
        invoicePhotoData = data
        isUploadingPhoto = true
        defer { isUploadingPhoto = false }
        do {
            let updated = try await FinancePyApi.shared.uploadPurchaseOrderInvoicePhoto(purchaseOrderId: poId, fileData: data, fileName: fileName)
            po = updated
            OfflineCache.shared.save(updated, key: "purchase_order_\(poId)")
        } catch {
            if NetworkMonitor.isConnectivityError(error) {
                let blobId = OfflineBlobStore.shared.saveBlob(data)
                OfflineOutbox.shared.enqueue(.uploadInvoicePhoto(entityType: .purchaseOrder, entityId: poId, blobId: blobId, fileName: fileName, mimeType: "image/jpeg"))
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func deleteInvoicePhoto() async {
        isUploadingPhoto = true
        defer { isUploadingPhoto = false }
        do {
            let updated = try await FinancePyApi.shared.deletePurchaseOrderInvoicePhoto(purchaseOrderId: poId)
            po = updated
            invoicePhotoData = nil
            OfflineCache.shared.save(updated, key: "purchase_order_\(poId)")
        } catch {
            if NetworkMonitor.isConnectivityError(error) {
                OfflineOutbox.shared.enqueue(.deleteInvoicePhoto(entityType: .purchaseOrder, entityId: poId))
                invoicePhotoData = nil
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func receivePurchaseOrder() async {
        isLoading = true
        do {
            let updated = try await FinancePyApi.shared.receivePurchaseOrder(id: poId)
            po = updated
            OfflineCache.shared.save(updated, key: "purchase_order_\(poId)")
        } catch {
            if NetworkMonitor.isConnectivityError(error) {
                OfflineOutbox.shared.enqueue(.receivePurchaseOrder(id: poId))
            } else {
                errorMessage = error.localizedDescription
            }
        }
        isLoading = false
    }

    private func cancelPurchaseOrder() async {
        isLoading = true
        do {
            let updated = try await FinancePyApi.shared.cancelPurchaseOrder(id: poId)
            po = updated
            OfflineCache.shared.save(updated, key: "purchase_order_\(poId)")
        } catch {
            if NetworkMonitor.isConnectivityError(error) {
                OfflineOutbox.shared.enqueue(.cancelPurchaseOrder(id: poId))
            } else {
                errorMessage = error.localizedDescription
            }
        }
        isLoading = false
    }

    // Each document carries its own currency (PYG has no decimals, USD has two),
    // so never a fixed "%.2f". The API may send the code lowercased ("pyg").
    private func money(_ amount: Double, _ currency: String) -> String {
        let code = currency.uppercased()
        return Formatters.formatCents(Formatters.doubleToCents(amount, currency: code), currency: code)
    }
}
