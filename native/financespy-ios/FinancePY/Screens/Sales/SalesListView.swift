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
                                    Text(sale.status.capitalized)
                                        .font(.caption)
                                        .foregroundColor(statusColor(for: sale.status))
                                    Spacer()
                                    Text("\(sale.currency.uppercased()) \(String(format: "%.2f", sale.total))")
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
}
