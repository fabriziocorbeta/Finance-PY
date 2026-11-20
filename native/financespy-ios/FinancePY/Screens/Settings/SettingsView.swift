import SwiftUI
import LocalAuthentication

struct SettingsView: View {
    // Clears the local SwiftData cache and flips the app back to LoginView --
    // AuthRepository.logout() only clears the Keychain token, so without this
    // the caller has to do both after either destructive action below.
    var onLoggedOut: () -> Void = {}

    @State private var settings: FamilySettingsDto?
    @State private var isLoading = true
    @State private var errorMessage: String?

    @State private var usage: UsageDto?

    @State private var showDeleteAccountAlert = false
    @State private var deleteAccountPassword = ""
    @State private var showDeleteAccountErrorAlert = false
    @State private var deleteAccountError: String? = nil
    @State private var showLogoutAlert = false
    @AppStorage("appLockEnabled") private var appLockEnabled = false
    @State private var showAppLockUnavailableAlert = false
    @State private var appLockUnavailableMessage: String? = nil

    private var appLockEnabledBinding: Binding<Bool> {
        Binding(
            get: { appLockEnabled },
            set: { newValue in
                if newValue {
                    let context = LAContext()
                    var authError: NSError?
                    if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &authError) {
                        appLockEnabled = true
                    } else {
                        appLockEnabled = false
                        appLockUnavailableMessage = authError?.localizedDescription
                            ?? "Configura Face ID, Touch ID o un código en el dispositivo antes de activar el bloqueo."
                        showAppLockUnavailableAlert = true
                    }
                } else {
                    appLockEnabled = false
                }
            }
        )
    }

    // We could add state here for pendingOutboxCount if we implemented a sync engine connection

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Cargando ajustes...")
                } else if let err = errorMessage {
                    VStack {
                        Text(err)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding()
                        Button("Reintentar") {
                            Task { await loadSettings() }
                        }
                    }
                } else if let settings = settings {
                    Form {
                        Section(header: Text("Perfil")) {
                            if let user = settings.currentUser {
                                let displayName = user.displayName ?? [user.firstName, user.lastName].compactMap { $0 }.joined(separator: " ").trimmingCharacters(in: .whitespaces)
                                let displayValue = displayName.isEmpty ? user.email : displayName

                                ProfileRow(label: "Nombre", value: displayValue)
                                ProfileRow(label: "Email", value: user.email)
                                ProfileRow(label: "Rol", value: user.role.uppercased())
                            } else {
                                Text("No hay información del perfil")
                                    .foregroundColor(.secondary)
                            }
                        }

                        let familyTitle = settings.name?.isEmpty == false ? "Familia (\(settings.name!))" : "Familia"
                        Section(header: Text(familyTitle)) {
                            let otherMembers = settings.users.filter { $0.id != settings.currentUser?.id }
                            if otherMembers.isEmpty {
                                Text("No hay otros miembros registrados")
                                    .foregroundColor(.secondary)
                            } else {
                                ForEach(otherMembers) { member in
                                    HStack {
                                        VStack(alignment: .leading) {
                                            let displayName = member.displayName ?? [member.firstName, member.lastName].compactMap { $0 }.joined(separator: " ").trimmingCharacters(in: .whitespaces)
                                            let displayValue = displayName.isEmpty ? member.email : displayName

                                            Text(displayValue)
                                                .font(.body)
                                                .fontWeight(.semibold)
                                            if displayValue != member.email {
                                                Text(member.email)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        Spacer()
                                        Text(member.role.uppercased())
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }

                        Section(header: Text("Navegación")) {
                            NavigationLink(destination: NavCustomizationView()) {
                                Label("Personalizar navegación", systemImage: "slider.horizontal.3")
                            }
                        }

                        Section(header: Text("Seguridad")) {
                            Toggle("Bloqueo con Face ID / código", isOn: appLockEnabledBinding)
                        }

                        if let usage = usage {
                            Section(header: Text("Uso y API")) {
                                ProfileRow(label: "Método de autenticación", value: usage.authenticationMethod ?? "N/A")
                                ProfileRow(label: "Mensaje", value: usage.message ?? "N/A")
                            }
                        }

                        Section {
                            Button(role: .destructive, action: {
                                showLogoutAlert = true
                            }) {
                                Text("Cerrar sesión")
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }

                            Button(role: .destructive, action: {
                                showDeleteAccountAlert = true
                            }) {
                                Text("Eliminar cuenta")
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Ajustes")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await loadSettings()
            }
            .alert("¿Cerrar sesión?", isPresented: $showLogoutAlert) {
                Button("Cancelar", role: .cancel) { }
                Button("Confirmar", role: .destructive) {
                    Task {
                        await AuthRepository.shared.logout()
                        onLoggedOut()
                    }
                }
            } message: {
                Text("¿Estás seguro de que deseas cerrar sesión? Tendrás que volver a ingresar tus credenciales.")
            }
            .alert("Error al eliminar", isPresented: $showDeleteAccountErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(deleteAccountError ?? "Ocurrió un error inesperado al eliminar la cuenta.")
            }
            .alert("No se puede activar el bloqueo", isPresented: $showAppLockUnavailableAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(appLockUnavailableMessage ?? "Configura Face ID, Touch ID o un código en el dispositivo antes de activar el bloqueo.")
            }

            .alert("¿Eliminar cuenta?", isPresented: $showDeleteAccountAlert) {
                SecureField("Contraseña actual", text: $deleteAccountPassword)
                Button("Cancelar", role: .cancel) {
                    deleteAccountPassword = ""
                }
                Button("Eliminar", role: .destructive) {
                    let password = deleteAccountPassword
                    deleteAccountPassword = ""
                    guard !password.isEmpty else {
                        showDeleteAccountAlert = false
                        deleteAccountError = "Ingresa tu contraseña actual para confirmar."
                        showDeleteAccountErrorAlert = true
                        return
                    }
                    Task {
                        do {
                            try await FinancePyApi.shared.deleteAccount(currentPassword: password)
                            await AuthRepository.shared.logout()
                            onLoggedOut()
                        } catch {
                            showDeleteAccountAlert = false
                            deleteAccountError = error.localizedDescription
                            showDeleteAccountErrorAlert = true
                        }
                    }
                }
            } message: {
                Text("Esta acción es irreversible y todos tus datos serán eliminados. Ingresa tu contraseña actual para confirmar.")
            }

        }
    }

    private func loadSettings() async {
        isLoading = true
        errorMessage = nil
        do {
            settings = try await FinancePyApi.shared.fetchFamilySettings()
            usage = try? await FinancePyApi.shared.fetchUsage()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

struct ProfileRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
