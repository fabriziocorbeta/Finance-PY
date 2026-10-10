import SwiftUI

struct BudgetDashboardView: View {
    @State private var budgetId: String? = nil
    @State private var budgetParam: String = "current"
    @State private var budget: BudgetDto? = nil
    @State private var isLoading = true
    @State private var error: String? = nil

    // Summary Tab State
    @State private var summaryTab: SummaryTab = .overview

    // Filter State
    @State private var categoryFilterTab: CategoryFilter = .all
    @State private var expandedGroups: Set<String> = []

    // Category sheet
    @State private var selectedCategory: BudgetCategoryDto? = nil

    enum SummaryTab {
        case overview
        case income
    }

    enum CategoryFilter {
        case all, overBudget, onTrack
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if isLoading {
                        ProgressView("Cargando presupuesto...")
                            .padding(.top, 40)
                    } else if let error = error {
                        Text(error)
                            .foregroundColor(.red)
                            .padding()
                        Button("Reintentar") {
                            Task { await loadBudget() }
                        }
                    } else if let budget = budget {
                        // Header Navigation
                        HStack {
                            Button(action: { navigateToBudget(budget.previousBudgetParam) }) {
                                Image(systemName: "chevron.left")
                            }
                            .disabled(budget.previousBudgetParam == nil)

                            Spacer()
                            Text(budget.name ?? "Presupuesto")
                                .font(.headline)
                            Spacer()

                            Button(action: { navigateToBudget(budget.nextBudgetParam) }) {
                                Image(systemName: "chevron.right")
                            }
                            .disabled(budget.nextBudgetParam == nil)
                        }
                        .padding(.horizontal)

                        if !budget.initialized {
                            // Uninitialized State
                            VStack(spacing: 16) {
                                Text("Este presupuesto no está configurado")
                                    .font(.headline)

                                Button("Comenzar desde cero") {
                                    Task { await startFromScratch() }
                                }
                                .buttonStyle(.borderedProminent)
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        } else {
                            // Allocated & Available Header
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Disponible para asignar")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Text(formatMoney(budget.availableToAllocate ?? 0, currency: budget.currency))
                                        .font(.title3)
                                        .bold()
                                        .foregroundColor((budget.availableToAllocate ?? 0) < 0 ? .red : .primary)
                                }
                                Spacer()
                                NavigationLink(destination: BudgetAllocationEditorView(budget: budget, onSaved: {
                                    Task { await loadBudget() }
                                })) {
                                    Text("Asignar")
                                        .font(.subheadline)
                                }
                                .buttonStyle(.bordered)
                            }
                            .padding(.horizontal)

                            // Donut Chart Placeholder (Simplified for iOS native)
                            VStack {
                                Text("Resumen de Gastos")
                                    .font(.subheadline)
                                HStack {
                                    Text("Gastado: \(formatMoney(budget.actualSpending ?? 0, currency: budget.currency))")
                                        .foregroundColor(.red)
                                    Spacer()
                                    Text("Presupuestado: \(formatMoney(budget.budgetedSpending ?? 0, currency: budget.currency))")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                            .padding(.horizontal)

                            // Summary Tabs
                            Picker("Resumen", selection: $summaryTab) {
                                Text("General").tag(SummaryTab.overview)
                                Text("Ingresos").tag(SummaryTab.income)
                            }
                            .pickerStyle(.segmented)
                            .padding(.horizontal)

                            if summaryTab == .overview {
                                OverviewSummaryView(budget: budget)
                            } else {
                                IncomeSummaryView(budget: budget)
                            }

                            // Categories Header
                            HStack {
                                Text("Categorías (\(budget.categories?.count ?? 0))")
                                    .font(.headline)
                                Spacer()
                                NavigationLink(destination: BudgetAllocationEditorView(budget: budget, onSaved: {
                                    Task { await loadBudget() }
                                })) {
                                    Text("Editar")
                                }
                                .buttonStyle(.bordered)
                            }
                            .padding(.horizontal)

                            if hasOverBudgetCategories(budget.categories) {
                                Picker("Filtro", selection: $categoryFilterTab) {
                                    Text("Todas").tag(CategoryFilter.all)
                                    Text("Sobre presupuesto").tag(CategoryFilter.overBudget)
                                    Text("En camino").tag(CategoryFilter.onTrack)
                                }
                                .pickerStyle(.segmented)
                                .padding(.horizontal)
                            }

                            // Category List
                            LazyVStack(spacing: 12) {
                                ForEach(filteredCategoryGroups(budget.categories ?? []), id: \.parent.id) { group in
                                    CategoryGroupView(
                                        group: group,
                                        currency: budget.currency ?? "USD",
                                        isExpanded: expandedGroups.contains(group.parent.id),
                                        onToggleExpand: {
                                            if expandedGroups.contains(group.parent.id) {
                                                expandedGroups.remove(group.parent.id)
                                            } else {
                                                expandedGroups.insert(group.parent.id)
                                            }
                                        },
                                        onSelect: { cat in
                                            selectedCategory = cat
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Presupuesto")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await loadBudget()
            }
            .sheet(item: $selectedCategory) { cat in
                CategoryDetailSheet(category: cat, currency: budget?.currency ?? "USD")
            }
        }
    }

    private func loadBudget() async {
        isLoading = true
        error = nil
        do {
            let fetched = try await FinancePyApi.shared.fetchBudget(id: budgetParam)
            self.budget = fetched
            self.budgetId = fetched.id
            if let categories = fetched.categories {
                self.expandedGroups = Set(categories.filter { !$0.subcategory }.map { $0.id })
            }
        } catch {
            self.error = "Error al cargar el presupuesto: \(error.localizedDescription)"
        }
        isLoading = false
    }

    private func navigateToBudget(_ param: String?) {
        guard let param = param else { return }
        budgetParam = param
        Task { await loadBudget() }
    }

    private func startFromScratch() async {
        isLoading = true
        do {
            let updated = try await FinancePyApi.shared.updateBudget(id: budgetId ?? budgetParam, expectedIncome: nil)
            self.budget = updated
        } catch {
            self.error = "Error al inicializar"
        }
        isLoading = false
    }

    // Helpers
    private func formatMoney(_ amount: Double, currency: String?) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency ?? "PYG"
        return formatter.string(from: NSNumber(value: amount)) ?? "\(currency ?? "PYG") \(amount)"
    }

    private func hasOverBudgetCategories(_ categories: [BudgetCategoryDto]?) -> Bool {
        return categories?.contains(where: { $0.overBudget }) ?? false
    }

    struct CategoryGroup {
        let parent: BudgetCategoryDto
        let subcategories: [BudgetCategoryDto]
    }

    private func filteredCategoryGroups(_ categories: [BudgetCategoryDto]) -> [CategoryGroup] {
        let parents = categories.filter { !$0.subcategory }
        let subcategories = categories.filter { $0.subcategory }

        var groups: [CategoryGroup] = []
        for parent in parents {
            let subs = subcategories.filter { $0.categoryParentId == parent.categoryId }

            let filteredSubs = subs.filter { cat in
                switch categoryFilterTab {
                case .all: return true
                case .overBudget: return cat.overBudget
                case .onTrack: return !cat.overBudget
                }
            }

            let parentMatches = (categoryFilterTab == .all) ||
                                (categoryFilterTab == .overBudget && parent.overBudget) ||
                                (categoryFilterTab == .onTrack && !parent.overBudget)

            if parentMatches || !filteredSubs.isEmpty {
                groups.append(CategoryGroup(parent: parent, subcategories: filteredSubs))
            }
        }
        return groups
    }
}

// Subviews

struct OverviewSummaryView: View {
    let budget: BudgetDto
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Presupuestado")
                Spacer()
                Text("\(budget.budgetedSpending ?? 0, specifier: "%.2f")")
            }
            HStack {
                Text("Gastado")
                Spacer()
                Text("\(budget.actualSpending ?? 0, specifier: "%.2f")")
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct IncomeSummaryView: View {
    let budget: BudgetDto
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Ingreso Esperado")
                Spacer()
                Text("\(budget.expectedIncome ?? 0, specifier: "%.2f")")
            }
            HStack {
                Text("Ingreso Real")
                Spacer()
                Text("\(budget.actualIncome ?? 0, specifier: "%.2f")")
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct CategoryGroupView: View {
    let group: BudgetDashboardView.CategoryGroup
    let currency: String
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let onSelect: (BudgetCategoryDto) -> Void

    var body: some View {
        VStack(spacing: 0) {
            CategoryRow(category: group.parent, currency: currency, hasSubs: !group.subcategories.isEmpty, isExpanded: isExpanded, onToggleExpand: onToggleExpand)
                .onTapGesture { onSelect(group.parent) }

            if isExpanded {
                ForEach(group.subcategories) { sub in
                    CategoryRow(category: sub, currency: currency, hasSubs: false, isExpanded: false, onToggleExpand: {})
                        .padding(.leading, 24)
                        .onTapGesture { onSelect(sub) }
                }
            }
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}

struct CategoryRow: View {
    let category: BudgetCategoryDto
    let currency: String
    let hasSubs: Bool
    let isExpanded: Bool
    let onToggleExpand: () -> Void

    var body: some View {
        HStack {
            if hasSubs {
                Button(action: onToggleExpand) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .foregroundColor(.secondary)
                }
            } else {
                Circle().fill(Color(hex: category.categoryColor ?? "#CCCCCC") ?? .gray)
                    .frame(width: 12, height: 12)
            }

            VStack(alignment: .leading) {
                Text(category.categoryName ?? "Categoría")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("\(formatMoney(category.actualSpending ?? 0)) / \(formatMoney(category.budgetedSpending ?? 0))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            let available = category.availableToSpend ?? 0
            Text(formatMoney(available))
                .font(.subheadline)
                .foregroundColor(category.overBudget ? .red : .primary)
        }
        .padding()
        .background(Color(.systemBackground))
        .overlay(
            Rectangle().frame(width: nil, height: 1, alignment: .bottom).foregroundColor(Color(.separator)),
            alignment: .bottom
        )
    }

    private func formatMoney(_ amount: Double) -> String {
        return "\(currency) \(amount)"
    }
}

struct CategoryDetailSheet: View {
    let category: BudgetCategoryDto
    let currency: String

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                Text(category.categoryName ?? "")
                    .font(.title)

                HStack {
                    Text("Presupuestado:")
                    Spacer()
                    Text("\(currency) \(category.budgetedSpending ?? 0, specifier: "%.2f")")
                }
                HStack {
                    Text("Gastado:")
                    Spacer()
                    Text("\(currency) \(category.actualSpending ?? 0, specifier: "%.2f")")
                }
                HStack {
                    Text("Disponible:")
                    Spacer()
                    Text("\(currency) \(category.availableToSpend ?? 0, specifier: "%.2f")")
                        .foregroundColor(category.overBudget ? .red : .primary)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Detalles de Categoría")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// Simple hex color extension
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        self.init(
            red: Double((rgb & 0xFF0000) >> 16) / 255.0,
            green: Double((rgb & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgb & 0x0000FF) / 255.0
        )
    }
}
