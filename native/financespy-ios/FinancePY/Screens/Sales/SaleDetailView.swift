import SwiftUI

struct SaleDetailView: View {
    let saleId: String
    @Environment(\.dismiss) private var dismiss

    @State private var sale: SaleDto?
    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var showCompleteAlert = false
    @State private var showCancelAlert = false

    @State private var invoicePhotoData: Data?
    @State private var isLoadingPhoto = false
    @State private var isUploadingPhoto = false

    var body: some View {
        Group {
            if isLoading && sale == nil {
                ProgressView()
            } else if let errorMessage = errorMessage {
                Text("Error: \(errorMessage)").foregroundColor(.red)
            } else if let sale = sale {
                List {
                    Section("Información General") {
                        LabeledContent("Estado", value: Formatters.saleStatusLabel(sale.status))
                        if let clientName = sale.clientName {
                            LabeledContent("Cliente", value: clientName)
                        }
                        LabeledContent("Total", value: money(sale.total, sale.currency))
                        if let notes = sale.notes {
                            LabeledContent("Notas", value: notes)
                        }
                    }

                    if let items = sale.saleItems, !items.isEmpty {
                        Section("Productos") {
                            ForEach(items, id: \.self) { item in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(item.productName ?? "Producto")
                                        Text("\(item.quantity) x \(money(item.unitPrice, sale.currency))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    if let sub = item.subtotal {
                                        Text(money(sub, sale.currency))
                                    }
                                }
                            }
                        }
                    }

                    Section("Foto de Factura") {
                        InvoicePhotoSectionView(
                            title: "Factura adjunta",
                            hasRemotePhoto: sale.hasInvoicePhoto ?? false,
                            remoteFilename: sale.invoicePhoto?.filename,
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
                        if sale.status == "draft" {
                            Button("Completar Venta") {
                                showCompleteAlert = true
                            }
                            .foregroundColor(.blue)

                            Button("Cancelar Venta") {
                                showCancelAlert = true
                            }
                            .foregroundColor(.red)
                        } else if sale.status == "completed" {
                            Button("Cancelar Venta") {
                                showCancelAlert = true
                            }
                            .foregroundColor(.red)
                        }
                    }
                }
                .navigationTitle("Detalle de Venta")
                .toolbar {
                    if sale.status == "draft" {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            NavigationLink("Editar", destination: SaleFormView(saleId: sale.id))
                        }
                    }
                }
            }
        }
        .task {
            await fetchSale()
        }
        .alert("Completar Venta", isPresented: $showCompleteAlert) {
            Button("Cancelar", role: .cancel) { }
            Button("Completar", role: .destructive) {
                Task { await completeSale() }
            }
        } message: {
            Text("¿Estás seguro de que deseas completar esta venta? Se descontará del stock.")
        }
        .alert("Cancelar Venta", isPresented: $showCancelAlert) {
            Button("Volver", role: .cancel) { }
            Button("Confirmar Cancelación", role: .destructive) {
                Task { await cancelSale() }
            }
        } message: {
            Text("¿Estás seguro de que deseas cancelar esta venta?")
        }
    }

    private func fetchSale() async {
        isLoading = true
        if sale == nil {
            sale = OfflineCache.shared.load(SaleDto.self, key: "sale_\(saleId)")
        }
        do {
            let fetched = try await FinancePyApi.shared.fetchSale(id: saleId)
            sale = fetched
            OfflineCache.shared.save(fetched, key: "sale_\(saleId)")
            if fetched.hasInvoicePhoto == true {
                await loadInvoicePhoto()
            }
        } catch {
            if sale == nil {
                errorMessage = error.localizedDescription
            }
        }
        isLoading = false
    }

    private func loadInvoicePhoto() async {
        isLoadingPhoto = true
        defer { isLoadingPhoto = false }
        if let data = try? await FinancePyApi.shared.downloadSaleInvoicePhoto(saleId: saleId) {
            invoicePhotoData = data
        }
    }

    private func uploadInvoicePhoto(data: Data, fileName: String) async {
        invoicePhotoData = data
        isUploadingPhoto = true
        defer { isUploadingPhoto = false }
        do {
            let updated = try await FinancePyApi.shared.uploadSaleInvoicePhoto(saleId: saleId, fileData: data, fileName: fileName)
            sale = updated
            OfflineCache.shared.save(updated, key: "sale_\(saleId)")
        } catch {
            if NetworkMonitor.isConnectivityError(error) {
                let blobId = OfflineBlobStore.shared.saveBlob(data)
                OfflineOutbox.shared.enqueue(.uploadInvoicePhoto(entityType: .sale, entityId: saleId, blobId: blobId, fileName: fileName, mimeType: "image/jpeg"))
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func deleteInvoicePhoto() async {
        isUploadingPhoto = true
        defer { isUploadingPhoto = false }
        do {
            let updated = try await FinancePyApi.shared.deleteSaleInvoicePhoto(saleId: saleId)
            sale = updated
            invoicePhotoData = nil
            OfflineCache.shared.save(updated, key: "sale_\(saleId)")
        } catch {
            if NetworkMonitor.isConnectivityError(error) {
                OfflineOutbox.shared.enqueue(.deleteInvoicePhoto(entityType: .sale, entityId: saleId))
                invoicePhotoData = nil
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func completeSale() async {
        isLoading = true
        do {
            let updated = try await FinancePyApi.shared.completeSale(id: saleId)
            sale = updated
            OfflineCache.shared.save(updated, key: "sale_\(saleId)")
        } catch {
            if NetworkMonitor.isConnectivityError(error) {
                OfflineOutbox.shared.enqueue(.completeSale(id: saleId))
            } else {
                errorMessage = error.localizedDescription
            }
        }
        isLoading = false
    }

    private func cancelSale() async {
        isLoading = true
        do {
            let updated = try await FinancePyApi.shared.cancelSale(id: saleId)
            sale = updated
            OfflineCache.shared.save(updated, key: "sale_\(saleId)")
        } catch {
            if NetworkMonitor.isConnectivityError(error) {
                OfflineOutbox.shared.enqueue(.cancelSale(id: saleId))
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
