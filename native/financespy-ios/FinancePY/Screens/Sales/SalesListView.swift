import SwiftUI

struct SalesListView: View {
    @State private var sales: [SaleDto] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && sales.isEmpty {
                    ProgressView("Cargando ventas...")
                } else if let errorMessage = errorMessage {
                    VStack {
                        Text("Error: \(errorMessage)")
                            .foregroundColor(.red)
                        Button("Reintentar") {
                            Task { await fetchSales() }
                        }
                        .padding()
                    }
                } else if sales.isEmpty {
                    Text("No hay ventas registradas.")
                        .foregroundColor(.secondary)
                } else {
                    List(sales) { sale in
                        NavigationLink(destination: SaleDetailView(saleId: sale.id)) {
                            VStack(alignment: .leading) {
                                Text(sale.clientName ?? "Sin cliente")
                                    .font(.headline)
                                HStack {
                                    Text(Formatters.saleStatusLabel(sale.status))
                                        .font(.caption)
                                        .foregroundColor(statusColor(for: sale.status))
                                    Spacer()
                                    Text(money(sale.total, sale.currency))
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
            .navigationTitle("Ventas")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: SaleFormView()) {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        Task { await fetchSales() }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .task {
                await fetchSales()
            }
        }
    }

    private func fetchSales() async {
        isLoading = true
        errorMessage = nil
        do {
            sales = try await FinancePyApi.shared.fetchSales()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func statusColor(for status: String) -> Color {
        switch status {
        case "completed": return .green
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
