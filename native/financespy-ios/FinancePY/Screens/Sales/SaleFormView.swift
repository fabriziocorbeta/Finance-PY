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
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
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
            if let id = saleId {
                _ = try await FinancePyApi.shared.updateSale(id: id, payload: payload)
            } else {
                _ = try await FinancePyApi.shared.createSale(payload: payload)
            }
            dismiss()
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
