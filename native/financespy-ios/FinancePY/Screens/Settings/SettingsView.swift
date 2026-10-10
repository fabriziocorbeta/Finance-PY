import SwiftUI

struct SettingsView: View {
    @State private var settings: FamilySettingsDto?
    @State private var isLoading = true
    @State private var errorMessage: String?

    @State private var usage: UsageDto?

    @State private var showDeleteAccountAlert = false
    @State private var showLogoutAlert = false

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
                    }
                }
            } message: {
                Text("¿Estás seguro de que deseas cerrar sesión? Tendrás que volver a ingresar tus credenciales.")
            }
            .alert("¿Eliminar cuenta?", isPresented: $showDeleteAccountAlert) {
                Button("Cancelar", role: .cancel) { }
                Button("Eliminar", role: .destructive) {
                    Task {
                        _ = try? await FinancePyApi.shared.deleteAccount()
                        await AuthRepository.shared.logout()
                    }
                }
            } message: {
                Text("Esta acción es irreversible y todos tus datos serán eliminados.")
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
