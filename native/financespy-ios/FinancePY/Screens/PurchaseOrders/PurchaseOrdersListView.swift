import SwiftUI

struct PurchaseOrdersListView: View {
    @State private var purchaseOrders: [PurchaseOrderDto] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && purchaseOrders.isEmpty {
                    ProgressView("Cargando órdenes de compra...")
                } else if let errorMessage = errorMessage {
                    VStack {
                        Text("Error: \(errorMessage)")
                            .foregroundColor(.red)
                        Button("Reintentar") {
                            Task { await fetchPurchaseOrders() }
                        }
                        .padding()
                    }
                } else if purchaseOrders.isEmpty {
                    Text("No hay órdenes de compra registradas.")
                        .foregroundColor(.secondary)
                } else {
                    List(purchaseOrders) { po in
                        NavigationLink(destination: PurchaseOrderDetailView(poId: po.id)) {
                            VStack(alignment: .leading) {
                                Text(po.supplierName ?? "Sin proveedor")
                                    .font(.headline)
                                HStack {
                                    Text(po.status.capitalized)
                                        .font(.caption)
                                        .foregroundColor(statusColor(for: po.status))
                                    Spacer()
                                    Text("\(po.currency.uppercased()) \(String(format: "%.2f", po.total))")
                                        .font(.subheadline)
                                        .bold()
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.plain)
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
        do {
            purchaseOrders = try await FinancePyApi.shared.fetchPurchaseOrders()
        } catch {
            errorMessage = error.localizedDescription
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
}
