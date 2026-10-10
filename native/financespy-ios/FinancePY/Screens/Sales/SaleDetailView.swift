import SwiftUI

struct SaleDetailView: View {
    let saleId: String
    @Environment(\.dismiss) private var dismiss

    @State private var sale: SaleDto?
    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var showCompleteAlert = false
    @State private var showCancelAlert = false

    var body: some View {
        Group {
            if isLoading && sale == nil {
                ProgressView()
            } else if let errorMessage = errorMessage {
                Text("Error: \(errorMessage)").foregroundColor(.red)
            } else if let sale = sale {
                List {
                    Section("Información General") {
                        LabeledContent("Estado", value: sale.status.capitalized)
                        if let clientName = sale.clientName {
                            LabeledContent("Cliente", value: clientName)
                        }
                        LabeledContent("Total", value: "\(sale.currency.uppercased()) \(String(format: "%.2f", sale.total))")
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
                                        Text("\(item.quantity) x \(String(format: "%.2f", item.unitPrice))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    if let sub = item.subtotal {
                                        Text(String(format: "%.2f", sub))
                                    }
                                }
                            }
                        }
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
        do {
            sale = try await FinancePyApi.shared.fetchSale(id: saleId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func completeSale() async {
        isLoading = true
        do {
            sale = try await FinancePyApi.shared.completeSale(id: saleId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func cancelSale() async {
        isLoading = true
        do {
            sale = try await FinancePyApi.shared.cancelSale(id: saleId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
