import SwiftUI

struct ProductsListView: View {
    @State private var products: [ProductDto] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    private let api = FinancePyApi.shared

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && products.isEmpty {
                    ProgressView("Cargando productos...")
                } else if let errorMessage = errorMessage {
                    VStack {
                        Text("Error: \(errorMessage)")
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding()
                        Button("Reintentar") {
                            Task {
                                await loadProducts()
                            }
                        }
                    }
                } else if products.isEmpty {
                    Text("No hay productos registrados.")
                        .foregroundColor(.secondary)
                } else {
                    List {
                        ForEach(products) { product in
                            NavigationLink(destination: ProductFormView(product: product, onSaved: {
                                Task { await loadProducts() }
                            })) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(product.name).font(.headline)
                                    if let category = product.category, !category.isEmpty {
                                        Text(category).font(.subheadline).foregroundColor(.secondary)
                                    }
                                    HStack {
                                        Text("Stock: \(product.stock)")
                                            .font(.caption)
                                            .foregroundColor(product.stock <= product.minStock ? .red : .primary)
                                        Spacer()
                                        Text("\(product.currency.uppercased()) \(String(format: "%.0f", product.sellPrice))")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .onDelete(perform: deleteProducts)
                    }
                    .refreshable {
                        await loadProducts()
                    }
                }
            }
            .navigationTitle("Productos")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: ProductFormView(product: nil, onSaved: {
                        Task { await loadProducts() }
                    })) {
                        Image(systemName: "plus")
                    }
                }
            }
            .onAppear {
                Task {
                    await loadProducts()
                }
            }
        }
    }

    private func loadProducts() async {
        isLoading = true
        errorMessage = nil
        do {
            products = try await api.getProducts()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func deleteProducts(at offsets: IndexSet) {
        let toDelete = offsets.map { products[$0] }
        for product in toDelete {
            Task {
                do {
                    try await api.deleteProduct(id: product.id)
                    await loadProducts()
                } catch {
                    errorMessage = "Error al eliminar: \(error.localizedDescription)"
                }
            }
        }
    }
}
