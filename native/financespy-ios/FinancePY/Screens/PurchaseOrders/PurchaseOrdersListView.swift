import SwiftUI

struct PurchaseOrdersListView: View {
    @State private var purchaseOrders: [PurchaseOrderDto] = []
    @State private var selectedStatus: String = "all"
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var filteredPurchaseOrders: [PurchaseOrderDto] {
        if selectedStatus == "all" { return purchaseOrders }
        return purchaseOrders.filter { $0.status == selectedStatus }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Estado", selection: $selectedStatus) {
                    Text("Todas").tag("all")
                    Text("Borrador").tag("draft")
                    Text("Recibidas").tag("received")
                    Text("Canceladas").tag("cancelled")
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                Group {
                    if isLoading && purchaseOrders.isEmpty {
                        ProgressView("Cargando órdenes de compra...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let errorMessage = errorMessage, purchaseOrders.isEmpty {
                        VStack {
                            Text("Error: \(errorMessage)")
                                .foregroundColor(.red)
                            Button("Reintentar") {
                                Task { await fetchPurchaseOrders() }
                            }
                            .padding()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if filteredPurchaseOrders.isEmpty {
                        Text("No hay órdenes de compra registradas.")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List(filteredPurchaseOrders) { po in
                            NavigationLink(destination: PurchaseOrderDetailView(poId: po.id)) {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(po.supplierName ?? "Sin proveedor")
                                            .font(.headline)
                                        Spacer()
                                        if po.hasInvoicePhoto == true {
                                            Image(systemName: "doc.text.image")
                                                .font(.caption)
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    HStack {
                                        Text(Formatters.purchaseOrderStatusLabel(po.status))
                                            .font(.caption)
                                            .foregroundColor(statusColor(for: po.status))
                                        Spacer()
                                        Text(money(po.total, po.currency))
                                            .font(.subheadline)
                                            .bold()
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .listStyle(.plain)
                        .refreshable {
                            await fetchPurchaseOrders()
                        }
                    }
                }
            }
            .navigationTitle("Órdenes de Compra")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: PurchaseOrderFormView()) {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        Task { await fetchPurchaseOrders() }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .task {
                await fetchPurchaseOrders()
            }
        }
    }

    private func fetchPurchaseOrders() async {
        isLoading = true
        errorMessage = nil
        if purchaseOrders.isEmpty, let cached = OfflineCache.shared.load([PurchaseOrderDto].self, key: "purchase_orders_list") {
            purchaseOrders = cached
        }
        do {
            let fetched = try await FinancePyApi.shared.fetchPurchaseOrders()
            purchaseOrders = fetched
            OfflineCache.shared.save(fetched, key: "purchase_orders_list")
        } catch {
            if purchaseOrders.isEmpty {
                errorMessage = error.localizedDescription
            }
        }
        isLoading = false
    }

    private func statusColor(for status: String) -> Color {
        switch status {
        case "received": return .green
        case "cancelled": return .red
        default: return .orange
        }
    }

    // Each document carries its own currency (PYG has no decimals, USD has two),
    // so never a fixed "%.2f". The API may send the code lowercased ("pyg").
    private func money(_ amount: Double, _ currency: String) -> String {
        let code = currency.uppercased()
        return Formatters.formatCents(Formatters.doubleToCents(amount, currency: code), currency: code)
    }
}
