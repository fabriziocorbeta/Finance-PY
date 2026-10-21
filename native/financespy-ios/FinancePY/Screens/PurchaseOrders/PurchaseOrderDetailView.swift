import SwiftUI

struct PurchaseOrderDetailView: View {
    let poId: String
    @Environment(\.dismiss) private var dismiss

    @State private var po: PurchaseOrderDto?
    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var showReceiveAlert = false
    @State private var showCancelAlert = false

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
        do {
            po = try await FinancePyApi.shared.fetchPurchaseOrder(id: poId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func receivePurchaseOrder() async {
        isLoading = true
        do {
            po = try await FinancePyApi.shared.receivePurchaseOrder(id: poId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func cancelPurchaseOrder() async {
        isLoading = true
        do {
            po = try await FinancePyApi.shared.cancelPurchaseOrder(id: poId)
        } catch {
            errorMessage = error.localizedDescription
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
