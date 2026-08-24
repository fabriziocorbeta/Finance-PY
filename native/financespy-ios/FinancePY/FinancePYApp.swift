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
                TransactionEntity.self
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
            DashboardView(syncEngine: syncEngine)
                .tabItem {
                    Label("Inicio", systemImage: "house.fill")
                }

            TransactionsView()
                .tabItem {
                    Label("Transacciones", systemImage: "list.bullet.rectangle")
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
            isLoggedIn = false
        }
    }
}
