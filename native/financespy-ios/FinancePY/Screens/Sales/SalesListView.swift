import SwiftUI

struct SalesListView: View {
    @State private var sales: [SaleDto] = []
    @State private var selectedStatus: String = "all"
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var filteredSales: [SaleDto] {
        if selectedStatus == "all" { return sales }
        return sales.filter { $0.status == selectedStatus }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Estado", selection: $selectedStatus) {
                    Text("Todas").tag("all")
                    Text("Borrador").tag("draft")
                    Text("Completadas").tag("completed")
                    Text("Canceladas").tag("cancelled")
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                Group {
                    if isLoading && sales.isEmpty {
                        ProgressView("Cargando ventas...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let errorMessage = errorMessage, sales.isEmpty {
                        VStack {
                            Text("Error: \(errorMessage)")
                                .foregroundColor(.red)
                            Button("Reintentar") {
                                Task { await fetchSales() }
                            }
                            .padding()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if filteredSales.isEmpty {
                        Text("No hay ventas registradas.")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List(filteredSales) { sale in
                            NavigationLink(destination: SaleDetailView(saleId: sale.id)) {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(sale.clientName ?? "Sin cliente")
                                            .font(.headline)
                                        Spacer()
                                        if sale.hasInvoicePhoto == true {
                                            Image(systemName: "doc.text.image")
                                                .font(.caption)
                                                .foregroundColor(.blue)
                                        }
                                    }
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
                        .refreshable {
                            await fetchSales()
                        }
                    }
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
        if sales.isEmpty, let cached = OfflineCache.shared.load([SaleDto].self, key: "sales_list") {
            sales = cached
        }
        do {
            let fetched = try await FinancePyApi.shared.fetchSales()
            sales = fetched
            OfflineCache.shared.save(fetched, key: "sales_list")
        } catch {
            if sales.isEmpty {
                errorMessage = error.localizedDescription
            }
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
