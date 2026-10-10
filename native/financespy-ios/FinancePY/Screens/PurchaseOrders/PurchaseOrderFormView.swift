import SwiftUI

struct PurchaseOrderFormView: View {
    var poId: String? // If nil, we are creating

    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var supplierName = ""
    @State private var currency = "pyg"
    @State private var expectedDate = ""
    @State private var notes = ""
    @State private var items: [PurchaseOrderItemAttributes] = []

    var body: some View {
        Form {
            if let errorMessage = errorMessage {
                Section {
                    Text(errorMessage).foregroundColor(.red)
                }
            }

            Section("Detalles Generales") {
                TextField("Proveedor", text: $supplierName)
                TextField("Moneda", text: $currency)
                TextField("Fecha Esperada (YYYY-MM-DD)", text: $expectedDate)
                TextField("Notas", text: $notes)
            }

            Section("Productos") {
                ForEach($items, id: \.uniqueId) { $item in
                    VStack(alignment: .leading) {
                        TextField("ID Producto", text: $item.productId)
                        HStack {
                            Stepper("Cantidad: \(item.quantity)", value: $item.quantity, in: 1...1000)
                            Spacer()
                            TextField("Costo Unitario", value: $item.unitCost, format: .number)
                                .keyboardType(.decimalPad)
                        }
                    }
                }
                .onDelete { indexSet in
                    items.remove(atOffsets: indexSet)
                }

                Button("Agregar Producto") {
                    items.append(PurchaseOrderItemAttributes(productId: "", quantity: 1, unitCost: 0.0))
                }
            }
        }
        .navigationTitle(poId == nil ? "Nueva OC" : "Editar OC")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Guardar") {
                    Task { await savePurchaseOrder() }
                }
                .disabled(isLoading)
            }
        }
        .task {
            if let id = poId {
                await loadPurchaseOrder(id: id)
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

    private func loadPurchaseOrder(id: String) async {
        isLoading = true
        do {
            let po = try await FinancePyApi.shared.fetchPurchaseOrder(id: id)
            self.supplierName = po.supplierName ?? ""
            self.currency = po.currency
            self.expectedDate = po.expectedDate ?? ""
            self.notes = po.notes ?? ""
            if let poItems = po.purchaseOrderItems {
                self.items = poItems.map {
                    PurchaseOrderItemAttributes(id: $0.id, productId: $0.productId, quantity: $0.quantity, unitCost: $0.unitCost)
                }
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func savePurchaseOrder() async {
        isLoading = true
        let payload = PurchaseOrderDataPayload(
            supplierName: supplierName,
            currency: currency,
            expectedDate: expectedDate.isEmpty ? nil : expectedDate,
            notes: notes,
            accountId: nil,
            purchaseOrderItemsAttributes: items
        )

        do {
            if let id = poId {
                _ = try await FinancePyApi.shared.updatePurchaseOrder(id: id, payload: payload)
            } else {
                _ = try await FinancePyApi.shared.createPurchaseOrder(payload: payload)
            }
            dismiss()
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
