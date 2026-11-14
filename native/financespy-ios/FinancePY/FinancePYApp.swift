import SwiftUI
import SwiftData
import LocalAuthentication

enum ModelContainerFactory {
    static let schema = Schema([
        AccountEntity.self,
        EntryEntity.self,
        TransactionEntity.self,
        ReceivableEntity.self
    ])

    static func makeContainer() -> ModelContainer {
        let persistentConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [persistentConfig])
        } catch {
            #if DEBUG
            print("Failed to open SwiftData container, resetting store: \(error.localizedDescription)")
            #endif
            removeStoreFiles(at: persistentConfig.url)

            do {
                return try ModelContainer(for: schema, configurations: [persistentConfig])
            } catch {
                #if DEBUG
                print("Failed to recreate persistent SwiftData container, falling back to in-memory: \(error.localizedDescription)")
                #endif
                let inMemoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                do {
                    return try ModelContainer(for: schema, configurations: [inMemoryConfig])
                } catch {
                    preconditionFailure("Unable to initialize SwiftData in-memory container: \(error.localizedDescription)")
                }
            }
        }
    }

    static func removeStoreFiles(at storeURL: URL) {
        let fileManager = FileManager.default
        let candidateURLs = [
            storeURL,
            URL(fileURLWithPath: storeURL.path + "-wal"),
            URL(fileURLWithPath: storeURL.path + "-shm")
        ]
        for url in candidateURLs where fileManager.fileExists(atPath: url.path) {
            try? fileManager.removeItem(at: url)
        }
    }
}

@MainActor
final class AppLockManager: ObservableObject {
    @Published var isLocked = false
    @Published var isAuthenticating = false
    @Published var errorMessage: String?

    private var shouldPromptOnForeground = false

    func lock() {
        isLocked = true
        shouldPromptOnForeground = true
        errorMessage = nil
    }

    func unlock() {
        isLocked = false
        shouldPromptOnForeground = false
        errorMessage = nil
    }

    func authenticateIfNeeded() async {
        guard isLocked, shouldPromptOnForeground else { return }
        await authenticate()
    }

    func authenticate() async {
        guard !isAuthenticating else { return }
        shouldPromptOnForeground = false
        isAuthenticating = true
        errorMessage = nil
        defer { isAuthenticating = false }

        let context = LAContext()
        context.localizedCancelTitle = "Cancelar"
        let reason = "Desbloquea FinancePY para acceder a tus finanzas."

        var authError: NSError?
        let policy: LAPolicy
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &authError) {
            policy = .deviceOwnerAuthenticationWithBiometrics
        } else if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &authError) {
            policy = .deviceOwnerAuthentication
        } else {
            errorMessage = authError?.localizedDescription ?? "Configura Face ID, Touch ID o código en el dispositivo."
            return
        }

        do {
            let success = try await context.evaluatePolicy(policy, localizedReason: reason)
            if success {
                unlock()
            }
        } catch let laError as LAError where
            laError.code == .biometryNotAvailable ||
            laError.code == .biometryNotEnrolled ||
            laError.code == .biometryLockout ||
            laError.code == .userFallback
        {
            let fallbackContext = LAContext()
            var fallbackError: NSError?
            if fallbackContext.canEvaluatePolicy(.deviceOwnerAuthentication, error: &fallbackError) {
                do {
                    let fallbackSuccess = try await fallbackContext.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
                    if fallbackSuccess {
                        unlock()
                    }
                } catch {
                    errorMessage = error.localizedDescription
                }
            } else {
                errorMessage = fallbackError?.localizedDescription ?? laError.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@main
struct FinancePYApp: App {
    @StateObject private var authRepository = AuthRepository.shared
    @StateObject private var appLockManager = AppLockManager()
    @AppStorage("appLockEnabled") private var appLockEnabled = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var isLoggedIn = false
    @State private var isCheckingAuth = true

    let container: ModelContainer

    init() {
        self.container = ModelContainerFactory.makeContainer()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                Group {
                    if isCheckingAuth {
                        ProgressView("Cargando...")
                    } else if isLoggedIn {
                        MainTabView(isLoggedIn: $isLoggedIn, container: container)
                    } else {
                        LoginView(isLoggedIn: $isLoggedIn)
                    }
                }

                if isLoggedIn && appLockEnabled && appLockManager.isLocked {
                    AppLockView(appLockManager: appLockManager)
                        .transition(.opacity)
                }

                if isLoggedIn && scenePhase != .active && !appLockManager.isAuthenticating {
                    PrivacyOverlayView()
                        .transition(.opacity)
                }
            }
            .task {
                // As the unit-test host, a logged-in simulator would otherwise sync against production.
                guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
                let loggedIn = await authRepository.isLoggedIn()
                if loggedIn && appLockEnabled {
                    appLockManager.lock()
                }
                self.isLoggedIn = loggedIn
                self.isCheckingAuth = false
                if loggedIn && appLockEnabled {
                    await appLockManager.authenticateIfNeeded()
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard isLoggedIn else { return }
                if newPhase == .background && appLockEnabled {
                    appLockManager.lock()
                } else if newPhase == .active && appLockEnabled {
                    Task {
                        await appLockManager.authenticateIfNeeded()
                    }
                }
            }
            .onChange(of: isLoggedIn) { _, newValue in
                if !newValue {
                    appLockManager.unlock()
                }
            }
            .onOpenURL { url in
                Task {
                    do {
                        try await authRepository.handleCallbackUrl(url)
                        self.isLoggedIn = true
                    } catch {
                        #if DEBUG
                        print("OAuth callback error: \(error.localizedDescription)")
                        #endif
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
            #if DEBUG
            print("Failed to fetch nav preferences: \(error)")
            #endif
        }

        do {
            let settings = try await FinancePyApi.shared.fetchFamilySettings()
            self.businessModeEnabled = settings.businessModeEnabled
        } catch {
            #if DEBUG
            print("Failed to fetch family settings: \(error)")
            #endif
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
            #if DEBUG
            print("Failed to clear local cache on logout: \(error.localizedDescription)")
            #endif
        }
    }
}

struct PrivacyOverlayView: View {
    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)
                Text("FinancePY")
                    .font(.title2.bold())
            }
        }
    }
}

struct AppLockView: View {
    @ObservedObject var appLockManager: AppLockManager

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)

                Text("FinancePY está bloqueado")
                    .font(.title3.bold())

                if let errorMessage = appLockManager.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Button("Desbloquear") {
                    Task {
                        await appLockManager.authenticate()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(appLockManager.isAuthenticating)
            }
            .padding()
        }
    }
}
