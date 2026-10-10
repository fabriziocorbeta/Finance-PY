import SwiftUI

struct GoalsListView: View {
    @State private var goals: [GoalDto] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && goals.isEmpty {
                    ProgressView("Cargando metas...")
                } else if let error = errorMessage {
                    VStack {
                        Text("Error")
                            .font(.headline)
                            .foregroundColor(.red)
                        Text(error)
                            .multilineTextAlignment(.center)
                            .padding()
                        Button("Reintentar") {
                            Task {
                                await loadGoals()
                            }
                        }
                        .padding(.top)
                    }
                } else if goals.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "target")
                            .font(.system(size: 64))
                            .foregroundColor(.secondary)
                        Text("No tenés metas aún.")
                            .font(.headline)
                        Text("¡Creá una nueva meta para empezar a planificar!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        NavigationLink(destination: GoalFormView()) {
                            Text("Nueva meta")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.accentColor)
                                .cornerRadius(10)
                                .padding(.horizontal)
                        }
                    }
                } else {
                    List {
                        ForEach(goals) { goal in
                            NavigationLink(destination: GoalDetailView(goalId: goal.id)) {
                                GoalRowView(goal: goal)
                            }
                        }
                    }
                    .refreshable {
                        await loadGoals()
                    }
                }
            }
            .navigationTitle("Metas")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: GoalFormView()) {
                        Image(systemName: "plus")
                    }
                }
            }
            .task {
                await loadGoals()
            }
        }
    }

    private func loadGoals() async {
        isLoading = true
        errorMessage = nil
        do {
            goals = try await FinancePyApi.shared.fetchGoals()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

struct GoalRowView: View {
    let goal: GoalDto

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(goal.name)
                    .font(.headline)
                Spacer()
                Text(formatState(goal.state))
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(stateColor(goal.state).opacity(0.1))
                    .foregroundColor(stateColor(goal.state))
                    .cornerRadius(8)
            }

            HStack {
                Text("Objetivo: \(formatTargetAmount(goal))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(goal.progressPercent ?? 0)%")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            let percentProgress = Double(max(0, min(100, goal.progressPercent ?? 0))) / 100.0
            ProgressView(value: percentProgress)
                .tint(Color.accentColor)
        }
        .padding(.vertical, 4)
    }

    private func formatTargetAmount(_ goal: GoalDto) -> String {
        let amount = Double(goal.targetAmount ?? "0") ?? 0
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = goal.currency ?? "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "\(goal.currency ?? "USD") \(amount)"
    }

    private func formatState(_ state: String?) -> String {
        switch state {
        case "active": return "Activa"
        case "paused": return "Pausada"
        case "completed": return "Completada"
        case "archived": return "Archivada"
        default: return "Activa"
        }
    }

    private func stateColor(_ state: String?) -> Color {
        switch state {
        case "active", .none: return .green
        case "paused": return .orange
        case "completed": return .blue
        case "archived": return .gray
        default: return .green
        }
    }
}
