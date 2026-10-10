import SwiftUI

struct ProductFormView: View {
    let product: ProductDto?
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    private let api = FinancePyApi.shared

    @State private var name: String = ""
    @State private var sku: String = ""
    @State private var category: String = ""
    @State private var supplier: String = ""
    @State private var buyPrice: String = "0"
    @State private var sellPrice: String = "0"
    @State private var currency: String = "pyg"
    @State private var minStock: String = "0"
    @State private var initialStock: String = "0"
    @State private var description: String = ""

    @State private var isSaving = false
    @State private var errorMessage: String? = nil

    init(product: ProductDto? = nil, onSaved: @escaping () -> Void) {
        self.product = product
        self.onSaved = onSaved
    }

    var body: some View {
        Form {
            Section(header: Text("Información Básica")) {
                TextField("Nombre", text: $name)
                TextField("SKU", text: $sku)
                TextField("Categoría", text: $category)
                TextField("Proveedor", text: $supplier)
            }

            Section(header: Text("Precios")) {
                TextField("Precio de Compra", text: $buyPrice)
                    .keyboardType(.decimalPad)
                TextField("Precio de Venta", text: $sellPrice)
                    .keyboardType(.decimalPad)
                Picker("Moneda", selection: $currency) {
                    Text("PYG").tag("pyg")
                    Text("USD").tag("usd")
                }
            }

            Section(header: Text("Inventario")) {
                if product == nil {
                    TextField("Stock Inicial", text: $initialStock)
                        .keyboardType(.numberPad)
                }
                TextField("Stock Mínimo", text: $minStock)
                    .keyboardType(.numberPad)
            }

            Section(header: Text("Descripción")) {
                TextEditor(text: $description)
                    .frame(height: 100)
            }

            if let errorMessage = errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }
            }

            Section {
                Button(action: saveProduct) {
                    if isSaving {
                        ProgressView().progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Text("Guardar Producto")
                            .frame(maxWidth: .infinity)
                            .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                    }
                }
                .disabled(isSaving || name.isEmpty)
            }
        }
        .navigationTitle(product == nil ? "Nuevo Producto" : "Editar Producto")
        .onAppear {
            if let product = product {
                name = product.name
                sku = product.sku ?? ""
                category = product.category ?? ""
                supplier = product.supplier ?? ""
                buyPrice = String(product.buyPrice)
                sellPrice = String(product.sellPrice)
                currency = product.currency
                minStock = String(product.minStock)
                description = product.description ?? ""
            }
        }
    }

    private func saveProduct() {
        isSaving = true
        errorMessage = nil

        let buyPriceValue = Double(buyPrice) ?? 0.0
        let sellPriceValue = Double(sellPrice) ?? 0.0
        let minStockValue = Int(minStock) ?? 0

        Task {
            do {
                if let product = product {
                    let request = UpdateProductRequest(product: UpdateProductBody(
                        name: name,
                        sku: sku.isEmpty ? nil : sku,
                        category: category.isEmpty ? nil : category,
                        supplier: supplier.isEmpty ? nil : supplier,
                        buyPrice: buyPriceValue,
                        sellPrice: sellPriceValue,
                        currency: currency,
                        minStock: minStockValue,
                        description: description.isEmpty ? nil : description
                    ))
                    _ = try await api.updateProduct(id: product.id, request: request)
                } else {
                    let initialStockValue = Int(initialStock) ?? 0
                    let request = CreateProductRequest(product: CreateProductBody(
                        name: name,
                        sku: sku.isEmpty ? nil : sku,
                        category: category.isEmpty ? nil : category,
                        supplier: supplier.isEmpty ? nil : supplier,
                        buyPrice: buyPriceValue,
                        sellPrice: sellPriceValue,
                        currency: currency,
                        minStock: minStockValue,
                        initialStock: initialStockValue,
                        description: description.isEmpty ? nil : description
                    ))
                    _ = try await api.createProduct(request: request)
                }
                onSaved()
                dismiss()
            } catch {
                errorMessage = "Error al guardar: \(error.localizedDescription)"
                isSaving = false
            }
        }
    }
}
