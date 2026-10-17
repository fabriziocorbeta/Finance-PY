import SwiftUI

struct NavItem: Identifiable, Equatable {
    let id: String
    let label: String
    let icon: String
}

let DEFAULT_NAV_POOL = [
    NavItem(id: "dashboard", label: "Inicio", icon: "house.fill"),
    NavItem(id: "transactions", label: "Transacciones", icon: "list.bullet.rectangle"),
    NavItem(id: "reports", label: "Reportes", icon: "chart.bar.fill"),
    NavItem(id: "budgets", label: "Presupuestos", icon: "chart.pie.fill"),
    NavItem(id: "goals", label: "Metas", icon: "target"),
    NavItem(id: "receivables", label: "Cuentas a Cobrar", icon: "arrow.down.forward.circle.fill"),
    NavItem(id: "debts", label: "Deudas", icon: "minus.circle.fill"),
    NavItem(id: "rules", label: "Reglas", icon: "gear"),
    NavItem(id: "chat", label: "Asistente", icon: "sparkles")
]

let BUSINESS_NAV_POOL = [
    NavItem(id: "products", label: "Productos", icon: "cart.fill"),
    NavItem(id: "sales", label: "Ventas", icon: "doc.text.fill"),
    NavItem(id: "purchase_orders", label: "Compras", icon: "shippingbox.fill"),
    NavItem(id: "fleet", label: "Flota", icon: "car.fill")
]

struct NavCustomizationView: View {
    @State private var selectedIds: [String] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var businessModeEnabled = false

    let maxSelectable = 5

    var pool: [NavItem] {
        businessModeEnabled ? DEFAULT_NAV_POOL + BUSINESS_NAV_POOL : DEFAULT_NAV_POOL
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Cargando preferencias...")
            } else if let err = errorMessage {
                VStack {
                    Text(err)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                    Button("Reintentar") {
                        Task { await loadPreferences() }
                    }
                }
            } else {
                List {
                    Section(header: Text("Seleccionados (\(selectedIds.count)/\(maxSelectable))"), footer: Text("El resto quedará disponible en el menú ☰.")) {
                        ForEach(selectedIds, id: \.self) { id in
                            if let item = pool.first(where: { $0.id == id }) {
                                NavCustomizationRow(item: item, isSelected: true) {
                                    toggleSelection(for: item.id)
                                }
                            }
                        }
                        .onMove(perform: moveSelectedItems)
                    }

                    let unselectedItems = pool.filter { !selectedIds.contains($0.id) }
                    if !unselectedItems.isEmpty {
                        Section(header: Text("Disponibles")) {
                            ForEach(unselectedItems) { item in
                                NavCustomizationRow(item: item, isSelected: false) {
                                    toggleSelection(for: item.id)
                                }
                            }
                        }
                    }

                    Section {
                        Button("Restaurar orden por defecto") {
                            selectedIds = ["dashboard", "transactions"]
                            savePreferences()
                        }
                        .foregroundColor(.blue)
                    }
                }
                .environment(\.editMode, .constant(.active)) // Enable drag to reorder immediately
            }
        }
        .navigationTitle("Personalizar navegación")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadPreferences()
        }
    }

    private func loadPreferences() async {
        isLoading = true
        errorMessage = nil
        do {
            let prefs = try await FinancePyApi.shared.fetchNavPreferences()
            if let order = prefs.navItemOrder, !order.isEmpty {
                self.selectedIds = order
            } else {
                self.selectedIds = ["dashboard", "transactions", "reports", "budgets", "goals", "receivables", "chat"]
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        do {
            let familySettings = try await FinancePyApi.shared.fetchFamilySettings()
            self.businessModeEnabled = familySettings.businessModeEnabled
        } catch {
            print("Failed to fetch family settings: \(error)")
        }

        isLoading = false
    }

    private func savePreferences() {
        let currentIds = selectedIds
        Task {
            do {
                _ = try await FinancePyApi.shared.updateNavPreferences(itemIds: currentIds)
            } catch {
                print("Error saving nav preferences: \(error)")
            }
        }
    }

    private func toggleSelection(for id: String) {
        if selectedIds.contains(id) {
            selectedIds.removeAll { $0 == id }
        } else {
            if selectedIds.count < maxSelectable {
                selectedIds.append(id)
            }
        }
        savePreferences()
    }

    private func moveSelectedItems(from source: IndexSet, to destination: Int) {
        selectedIds.move(fromOffsets: source, toOffset: destination)
        savePreferences()
    }
}

struct NavCustomizationRow: View {
    let item: NavItem
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack {
            Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                .foregroundColor(isSelected ? .blue : .gray)
                .onTapGesture {
                    onToggle()
                }

            Image(systemName: item.icon)
                .frame(width: 24, height: 24)
                .foregroundColor(.secondary)

            Text(item.label)
                .foregroundColor(.primary)

            Spacer()
        }
        // Remove default list padding and tap action to avoid conflicts with editMode (.onMove)
        .contentShape(Rectangle())
    }
}

struct NavCustomizationView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            NavCustomizationView()
        }
    }
}
