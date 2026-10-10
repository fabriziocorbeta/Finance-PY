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

    init(isLoggedIn: Binding<Bool>, container: ModelContainer) {
        self._isLoggedIn = isLoggedIn
        self.container = container
        self._syncEngine = StateObject(wrappedValue: SyncEngine(modelContext: container.mainContext))
    }

    var body: some View {
        TabView {
BudgetDashboardView()
    .tabItem {
        Label("Presupuesto", systemImage: "chart.pie.fill")
    }

            DashboardView(syncEngine: syncEngine)
                .tabItem {
                    Label("Inicio", systemImage: "house.fill")
                }

            TransactionsView()
                .tabItem {
                    Label("Transacciones", systemImage: "list.bullet.rectangle")
                }

            ProductsListView()
                .tabItem {
                    Label("Productos", systemImage: "cart.fill")
                }

            RulesListView()
                .tabItem {
                    Label("Reglas", systemImage: "gear")
                }

            ReceivablesListView()
                .tabItem {
                    Label("Cuentas", systemImage: "dollarsign.circle")
                }

            ReportsView()
                .tabItem {
                    Label("Reportes", systemImage: "chart.pie.fill")
                }

            GoalsListView()
                .tabItem {
                    Label("Metas", systemImage: "target")
                }

            ChatsListView()
                .tabItem {
                    Label("Asistente IA", systemImage: "sparkles")
                }

            FleetListView()
                .tabItem {
                    Label("Flota", systemImage: "car.fill")
                }

            ImportsView()
                .tabItem {
                    Label("Importaciones", systemImage: "square.and.arrow.down.on.square")
                }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: performLogout) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                }
            }
        }
    }

    private func performLogout() {
        Task {
            await AuthRepository.shared.logout()
            clearLocalCache()
            isLoggedIn = false
        }
    }

    // Logout only cleared the Keychain token -- the local SwiftData cache
    // (synced from whoever was logged in before) stayed on disk and kept
    // rendering in the UI for whichever account logs in next on the same
    // device/simulator, until a fresh SyncEngine pass happened to overwrite
    // it. Wipe it here so switching accounts never shows stale data from
    // the previous session, even for a moment.
    private func clearLocalCache() {
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
