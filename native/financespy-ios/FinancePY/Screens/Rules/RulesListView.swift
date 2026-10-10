import SwiftUI

struct RulesListView: View {
    @State private var rules: [RuleDto] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    private let api = FinancePyApi.shared

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && rules.isEmpty {
                    ProgressView("Cargando reglas...")
                } else if let errorMessage = errorMessage {
                    VStack {
                        Text("Error: \(errorMessage)")
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding()
                        Button("Reintentar") {
                            Task {
                                await loadRules()
                            }
                        }
                    }
                } else if rules.isEmpty {
                    Text("No hay reglas registradas.")
                        .foregroundColor(.secondary)
                } else {
                    List {
                        ForEach(rules) { rule in
                            NavigationLink(destination: RuleDetailView(rule: rule, onDeleted: {
                                Task { await loadRules() }
                            })) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(rule.name ?? "Regla sin nombre").font(.headline)
                                    HStack {
                                        Text(rule.resourceType)
                                            .font(.caption)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.blue.opacity(0.1))
                                            .cornerRadius(4)

                                        if rule.active {
                                            Text("Activa")
                                                .font(.caption)
                                                .foregroundColor(.green)
                                        } else {
                                            Text("Inactiva")
                                                .font(.caption)
                                                .foregroundColor(.red)
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .refreshable {
                        await loadRules()
                    }
                }
            }
            .navigationTitle("Reglas")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: RuleFormView(rule: nil, onSaved: {
                        Task { await loadRules() }
                    })) {
                        Image(systemName: "plus")
                    }
                }
            }
            .onAppear {
                Task {
                    await loadRules()
                }
            }
        }
    }

    private func loadRules() async {
        isLoading = true
        errorMessage = nil
        do {
            rules = try await api.getRules()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
