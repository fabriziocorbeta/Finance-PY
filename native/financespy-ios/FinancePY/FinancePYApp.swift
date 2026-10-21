import SwiftUI
import SwiftData

@main
struct FinancePYApp: App {
    @StateObject private var authRepository = AuthRepository.shared
    @State private var isLoggedIn = false
    @State private var isCheckingAuth = true

    let container: ModelContainer

    init() {
        do {
            let schema = Schema([
                AccountEntity.self,
                EntryEntity.self,
                TransactionEntity.self,
                ReceivableEntity.self
            ])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            self.container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to initialize SwiftData container: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if isCheckingAuth {
                    ProgressView("Cargando...")
                } else if isLoggedIn {
                    MainTabView(isLoggedIn: $isLoggedIn, container: container)
                } else {
                    LoginView(isLoggedIn: $isLoggedIn)
                }
            }
            .task {
                // As the unit-test host, a logged-in simulator would otherwise sync against production.
                guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
                self.isLoggedIn = await authRepository.isLoggedIn()
                self.isCheckingAuth = false
            }
            .onOpenURL { url in
                Task {
                    do {
                        try await authRepository.handleCallbackUrl(url)
                        self.isLoggedIn = true
                    } catch {
                        print("OAuth callback error: \(error.localizedDescription)")
                    }
                }
            }
        }
        .modelContainer(container)
    }
}

struct MainTabView: View {
    @Binding var isLoggedIn: Bool
    let container: ModelContainer

    @StateObject private var syncEngine: SyncEngine
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Query private var accounts: [AccountEntity]
    @State private var isCheckingAccounts = true
    @State private var shouldShowOnboarding = false

    @State private var navItemOrder: [String] = ["dashboard", "transactions", "reports", "budgets", "goals", "receivables", "chat"]
    @State private var businessModeEnabled = false

    init(isLoggedIn: Binding<Bool>, container: ModelContainer) {
        self._isLoggedIn = isLoggedIn
        self.container = container
        self._syncEngine = StateObject(wrappedValue: SyncEngine(modelContext: container.mainContext))
    }

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                mainTabs
            } else if isCheckingAccounts {
                ProgressView("Cargando...")
                    .task {
                        await checkOnboardingStatus()
                    }
            } else if shouldShowOnboarding {
                NavigationStack {
                    OnboardingView(onComplete: {
                        hasCompletedOnboarding = true
                    })
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Omitir") {
                                hasCompletedOnboarding = true
                            }
                        }
                    }
                }
            } else {
                mainTabs
            }
        }
    }

    private var mainTabs: some View {
        let pool = businessModeEnabled ? DEFAULT_NAV_POOL + BUSINESS_NAV_POOL : DEFAULT_NAV_POOL

        // Take at most 5 for the main tabs. Usually TabView in iOS allows up to 5 icons in the bar,
        // and automatically puts the rest in a "More" tab, but we'll manage it explicitly to match the requirement.
        let mainTabIds = Array(navItemOrder.prefix(4)) // Reserve 1 for More/Settings

        return TabView {
            ForEach(mainTabIds, id: \.self) { id in
                if let item = pool.first(where: { $0.id == id }) {
                    viewForId(id)
                        .tabItem {
                            Label(item.label, systemImage: item.icon)
                        }
                }
            }

            NavigationStack {
                List {
                    Section {
                        let moreIds = pool.map { $0.id }.filter { !mainTabIds.contains($0) }
                        ForEach(moreIds, id: \.self) { id in
                            if let item = pool.first(where: { $0.id == id }) {
                                NavigationLink(destination: viewForId(id)) {
                                    Label(item.label, systemImage: item.icon)
                                }
                            }
                        }
                    }

                    Section {
                        NavigationLink(destination: ImportsView()) {
                            Label("Importaciones", systemImage: "square.and.arrow.down.on.square")
                        }

                        NavigationLink(destination: SettingsView(onLoggedOut: {
                            clearLocalCache()
                            isLoggedIn = false
                        })) {
                            Label("Ajustes", systemImage: "gearshape.fill")
                        }
                    }
                }
                .navigationTitle("Más")
            }
            .tabItem {
                Label("Más", systemImage: "ellipsis")
            }
        }
    }

    @ViewBuilder
    private func viewForId(_ id: String) -> some View {
        switch id {
        case "dashboard": DashboardView(syncEngine: syncEngine)
        case "transactions": TransactionsView()
        case "reports": ReportsView()
        case "budgets": BudgetDashboardView()
        case "goals": GoalsListView()
        case "receivables": ReceivablesListView()
        case "debts": DebtsListView()
        case "rules": RulesListView()
        case "chat": ChatsListView()
        case "products": ProductsListView()
        case "sales": SalesListView()
        case "purchase_orders": PurchaseOrdersListView()
        case "fleet": FleetListView()
        default: Text("Vista no encontrada")
        }
    }

    // Logout only cleared the Keychain token -- the local SwiftData cache
    // (synced from whoever was logged in before) stayed on disk and kept
    // rendering in the UI for whichever account logs in next on the same
    // device/simulator, until a fresh SyncEngine pass happened to overwrite
    // it. Wipe it here so switching accounts never shows stale data from
    // the previous session, even for a moment.
    private func checkOnboardingStatus() async {
        if hasCompletedOnboarding {
            isCheckingAccounts = false
            return
        }

        if !accounts.isEmpty {
            hasCompletedOnboarding = true
            isCheckingAccounts = false
            return
        }

        do {
            let remoteAccounts = try await FinancePyApi.shared.fetchAllAccounts()
            if remoteAccounts.isEmpty {
                shouldShowOnboarding = true
            } else {
                hasCompletedOnboarding = true
            }
        } catch {
            // On error, default to showing onboarding if they have no accounts locally
            shouldShowOnboarding = true
        }

        do {
            let prefs = try await FinancePyApi.shared.fetchNavPreferences()
            if let order = prefs.navItemOrder, !order.isEmpty {
                self.navItemOrder = order
            }
        } catch {
            print("Failed to fetch nav preferences: \(error)")
        }

        do {
            let settings = try await FinancePyApi.shared.fetchFamilySettings()
            self.businessModeEnabled = settings.businessModeEnabled
        } catch {
            print("Failed to fetch family settings: \(error)")
        }

        isCheckingAccounts = false
    }

    private func clearLocalCache() {
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
        let context = container.mainContext
        do {
            try context.delete(model: TransactionEntity.self)
            try context.delete(model: EntryEntity.self)
            try context.delete(model: AccountEntity.self)
            try context.delete(model: ReceivableEntity.self)
            try context.save()
        } catch {
            print("Failed to clear local cache on logout: \(error.localizedDescription)")
        }
    }
}
