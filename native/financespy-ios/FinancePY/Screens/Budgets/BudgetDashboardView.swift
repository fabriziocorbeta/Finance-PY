import SwiftUI

struct BudgetDashboardView: View {
    @State private var budgetId: String? = nil
    @State private var budgetParam: String = "current"
    @State private var budget: BudgetDto? = nil
    @State private var isLoading = true
    @State private var error: String? = nil
    @State private var loadTask: Task<Void, Never>? = nil

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
        loadTask?.cancel()

        let task = Task { @MainActor in
            guard !Task.isCancelled else { return }
            isLoading = true
            error = nil
            do {
                var targetId = budgetParam
                var foundSummary: BudgetDto? = nil

                // If the budgetParam is not a specific ID (like "current" or a "YYYY-MM" prefix),
                // resolve it by fetching the list of all budgets first, just like the Android app does.
                if !targetId.contains("-") || targetId.count <= 7 {
                    if targetId == "current" {
                        let date = Date()
                        let calendar = Calendar.current
                        let year = calendar.component(.year, from: date)
                        let month = calendar.component(.month, from: date)
                        targetId = String(format: "%04d-%02d", year, month)
                    }

                    do {
                        let allBudgets = try await FinancePyApi.shared.fetchAllBudgets()
                        guard !Task.isCancelled else { return }
                        if let summary = allBudgets.first(where: {
                            ($0.startDate?.hasPrefix(targetId) == true) || $0.param == targetId
                        }) {
                            foundSummary = summary
                            targetId = summary.id
                        }
                    } catch {
                        // Ignore error, will attempt to fetch by budgetParam and probably fail or succeed fallback
                    }
                }

                guard !Task.isCancelled else { return }

                do {
                    let fetched = try await FinancePyApi.shared.fetchBudget(id: targetId)
                    guard !Task.isCancelled else { return }
                    self.budget = fetched
                    self.budgetId = fetched.id
                    if let categories = fetched.categories {
                        self.expandedGroups = Set(categories.filter { !$0.subcategory }.map { $0.id })
                    }
                } catch {
                    guard !Task.isCancelled else { return }
                    if let summary = foundSummary {
                        self.budget = summary
                        self.budgetId = summary.id
                        self.error = "Error al cargar los detalles del presupuesto, mostrando resumen."
                    } else {
                        // If no budget is found, try creating it
                        if budgetParam == "current" || targetId.count == 7 { // YYYY-MM
                            let startDate = targetId + "-01"
                            do {
                                let created = try await FinancePyApi.shared.createBudget(expectedIncome: 0, startDate: startDate, endDate: nil)
                                guard !Task.isCancelled else { return }
                                self.budget = created
                                self.budgetId = created.id
                                if let categories = created.categories {
                                    self.expandedGroups = Set(categories.filter { !$0.subcategory }.map { $0.id })
                                }
                            } catch NetworkError.httpError(let code, let message) where code == 422 {
                                // If we hit a race condition across devices/sessions where the budget was just created
                                // and the DB correctly rejects the duplicate dates, gracefully fetch the now-existing budget.
                                // Don't match on the message: it's localized ("ya está en uso" / "has already been taken").
                                let allBudgets = try await FinancePyApi.shared.fetchAllBudgets()
                                guard !Task.isCancelled else { return }
                                if let summary = allBudgets.first(where: {
                                    ($0.startDate?.hasPrefix(targetId) == true) || $0.param == targetId
                                }) {
                                    let fallbackFetched = try await FinancePyApi.shared.fetchBudget(id: summary.id)
                                    guard !Task.isCancelled else { return }
                                    self.budget = fallbackFetched
                                    self.budgetId = fallbackFetched.id
                                    if let categories = fallbackFetched.categories {
                                        self.expandedGroups = Set(categories.filter { !$0.subcategory }.map { $0.id })
                                    }
                                } else {
                                    throw NetworkError.httpError(code, message)
                                }
                            }
                        } else {
                            throw error
                        }
                    }
                }
            } catch {
                guard !Task.isCancelled else { return }
                self.error = "Error al cargar el presupuesto: \(error.localizedDescription)"
                self.budget = nil
            }
            guard !Task.isCancelled else { return }
            isLoading = false
        }
        self.loadTask = task
        await task.value
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
