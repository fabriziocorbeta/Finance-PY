import SwiftUI

struct GoalDetailView: View {
    let goalId: String
    @Environment(\.presentationMode) var presentationMode

    @State private var goal: GoalDto? = nil
    @State private var pledges: [GoalPledgeDto] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    @State private var isDeleting = false

    // Pledge Dialog State
    @State private var showingPledgeDialog = false
    @State private var allAccounts: [AccountDto] = []
    @State private var pledgeAccountId: String = ""
    @State private var pledgeAmount: String = ""
    @State private var pledgeError: String? = nil
    @State private var isSavingPledge = false

    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView("Cargando meta...")
                    .padding()
            } else if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            } else if let goal = goal {
                VStack(spacing: 16) {
                    goalCard(goal)

                    if let status = goal.status {
                        statusCard(goal: goal, status: status)
                    }

                    actionsCard(goal)

                    pledgesCard(goal)
                }
                .padding()
            }
        }
        .navigationTitle("Detalle de Meta")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if goal != nil {
                    NavigationLink(destination: GoalFormView(goalId: goalId)) {
                        Text("Editar")
                    }
                }
            }
        }
        .task {
            await loadData()
        }
        .sheet(isPresented: $showingPledgeDialog) {
            pledgeDialogView
        }
        .alert("Error", isPresented: .constant(pledgeError != nil), actions: {
            Button("OK") { pledgeError = nil }
        }, message: {
            if let pledgeError = pledgeError {
                Text(pledgeError)
            }
        })
    }

    private func loadData() async {
        isLoading = true
        errorMessage = nil
        do {
            let api = FinancePyApi.shared

            async let fetchedGoal = api.fetchGoal(id: goalId)
            async let fetchedPledges = api.fetchGoalPledges(goalId: goalId)
            async let fetchedAccounts = api.fetchAllAccounts()

            goal = try await fetchedGoal
            pledges = try await fetchedPledges

            let all = try await fetchedAccounts
            let linkedIds = goal?.accountIds ?? []

            if linkedIds.isEmpty {
                allAccounts = all
            } else {
                allAccounts = all.filter { linkedIds.contains($0.id) }
            }

            if let firstId = allAccounts.first?.id, pledgeAccountId.isEmpty {
                pledgeAccountId = firstId
            }

        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func goalCard(_ goal: GoalDto) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(goal.name)
                .font(.title2)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 8) {
                infoRow(label: "Monto objetivo:", value: formatMoney(goal.targetAmount, currency: goal.currency))
                if let bal = goal.currentBalance {
                    infoRow(label: "Balance actual:", value: formatMoney(bal, currency: goal.currency))
                }
                if let rem = goal.remainingAmount {
                    infoRow(label: "Monto restante:", value: formatMoney(rem, currency: goal.currency))
                }
                if let date = goal.targetDate {
                    infoRow(label: "Fecha objetivo:", value: date)
                }
                if let notes = goal.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notas:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(notes)
                            .font(.subheadline)
                    }
                }

                HStack {
                    Text("Estado:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(formatState(goal.state))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(stateColor(goal.state))
                }
            }

            VStack(spacing: 4) {
                HStack {
                    Text("Progreso")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(goal.progressPercent ?? 0)%")
                        .font(.subheadline)
                        .fontWeight(.bold)
                }
                let percentProgress = Double(max(0, min(100, goal.progressPercent ?? 0))) / 100.0
                ProgressView(value: percentProgress)
                    .tint(.accentColor)
            }
            .padding(.top, 8)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func statusCard(goal: GoalDto, status: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.accentColor)
                Text(formatTrackingStatus(status))
                    .font(.headline)
                    .foregroundColor(.primary)
            }

            if let months = goal.monthsRemaining {
                Text("Meses restantes: \(months)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            if let pace = goal.pace {
                Text("Ritmo sugerido: \(formatMoney(pace, currency: goal.currency)) / mes")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            if let delta = goal.catchUpDelta {
                Text("Atraso actual: \(formatMoney(delta, currency: goal.currency))")
                    .font(.subheadline)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func actionsCard(_ goal: GoalDto) -> some View {
        VStack(spacing: 12) {
            let isArchived = goal.state == "archived"
            let isCompleted = goal.state == "completed"
            let isPaused = goal.state == "paused"

            if !isArchived && !isCompleted {
                if isPaused {
                    Button("Reanudar meta") {
                        updateState("active")
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                } else {
                    Button("Pausar meta") {
                        updateState("paused")
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                }

                Button("Marcar como completada") {
                    updateState("completed")
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
            }

            Button("Borrar meta") {
                deleteGoal()
            }
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.red)
            .cornerRadius(10)
            .disabled(isDeleting)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func pledgesCard(_ goal: GoalDto) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Compromisos")
                    .font(.headline)
                Spacer()

                let isArchivedOrCompleted = goal.state == "archived" || goal.state == "completed"
                if !isArchivedOrCompleted {
                    Button(action: {
                        pledgeAmount = ""
                        showingPledgeDialog = true
                    }) {
                        Text("Agregar")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                }
            }

            if pledges.isEmpty {
                Text("No hay compromisos de aporte")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                let openPledges = pledges.filter { $0.state == "open" }
                let closedPledges = pledges.filter { $0.state != "open" }

                if !openPledges.isEmpty {
                    Text("Abiertos")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)

                    ForEach(openPledges) { pledge in
                        pledgeRow(pledge)
                    }
                }

                if !closedPledges.isEmpty {
                    Text("Anteriores")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)

                    ForEach(closedPledges) { pledge in
                        pledgeRow(pledge)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func pledgeRow(_ pledge: GoalPledgeDto) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(formatMoney(pledge.amount, currency: pledge.currency))
                    .font(.subheadline)
                    .fontWeight(.bold)

                // Note: We don't have account name in GoalPledgeDto currently in our Swift struct,
                // so we just show the status and date.

                HStack {
                    Text(formatPledgeState(pledge.state))
                        .font(.caption)
                        .foregroundColor(pledge.state == "open" ? .green : .secondary)

                    if let date = pledge.createdAt {
                        Text("• \(String(date.prefix(10)))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            if pledge.state == "open" {
                HStack(spacing: 12) {
                    Button(action: {
                        renewPledge(pledgeId: pledge.id)
                    }) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(.primary)
                    }

                    Button(action: {
                        cancelPledge(pledgeId: pledge.id)
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(8)
    }

    private var pledgeDialogView: some View {
        NavigationStack {
            Form {
                Section(header: Text("Cuenta de aporte")) {
                    if allAccounts.isEmpty {
                        Text("No hay cuentas disponibles")
                            .foregroundColor(.secondary)
                    } else {
                        Picker("Cuenta", selection: $pledgeAccountId) {
                            ForEach(allAccounts, id: \.id) { account in
                                Text(account.name).tag(account.id)
                            }
                        }
                    }
                }

                Section(header: Text("Importe")) {
                    TextField("0.00", text: $pledgeAmount)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Agregar compromiso")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") {
                        showingPledgeDialog = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Guardar") {
                        createPledge()
                    }
                    .disabled(isSavingPledge || pledgeAmount.isEmpty || pledgeAccountId.isEmpty)
                }
            }
            .overlay {
                if isSavingPledge {
                    ProgressView()
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }

    // MARK: - Actions

    private func updateState(_ newState: String) {
        Task {
            isLoading = true
            do {
                let body = UpdateGoalBody(name: nil, targetAmount: nil, currency: nil, targetDate: nil, color: nil, icon: nil, notes: nil, state: newState, accountIds: nil, allocations: nil, goalAccountsAttributes: nil)
                goal = try await FinancePyApi.shared.updateGoal(id: goalId, body: body)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func deleteGoal() {
        Task {
            isDeleting = true
            do {
                if goal?.state != "archived" {
                    _ = try await FinancePyApi.shared.updateGoal(id: goalId, body: UpdateGoalBody(name: nil, targetAmount: nil, currency: nil, targetDate: nil, color: nil, icon: nil, notes: nil, state: "archived", accountIds: nil, allocations: nil, goalAccountsAttributes: nil))
                }
                try await FinancePyApi.shared.deleteGoal(id: goalId)
                presentationMode.wrappedValue.dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isDeleting = false
            }
        }
    }

    private func createPledge() {
        guard let amount = Double(pledgeAmount), amount > 0 else {
            pledgeError = "Ingresá un monto válido"
            return
        }

        Task {
            isSavingPledge = true
            do {
                let body = CreateGoalPledgeBody(amount: amount, accountId: pledgeAccountId)
                _ = try await FinancePyApi.shared.createGoalPledge(goalId: goalId, body: body)
                showingPledgeDialog = false
                pledges = try await FinancePyApi.shared.fetchGoalPledges(goalId: goalId)
            } catch {
                pledgeError = error.localizedDescription
            }
            isSavingPledge = false
        }
    }

    private func cancelPledge(pledgeId: String) {
        Task {
            do {
                try await FinancePyApi.shared.cancelGoalPledge(goalId: goalId, pledgeId: pledgeId)
                pledges = try await FinancePyApi.shared.fetchGoalPledges(goalId: goalId)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func renewPledge(pledgeId: String) {
        Task {
            do {
                _ = try await FinancePyApi.shared.renewGoalPledge(goalId: goalId, pledgeId: pledgeId)
                pledges = try await FinancePyApi.shared.fetchGoalPledges(goalId: goalId)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Formatters

    private func formatMoney(_ amountStr: String?, currency: String?) -> String {
        let amount = Double(amountStr ?? "0") ?? 0
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency ?? "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "\(currency ?? "USD") \(amount)"
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

    private func formatTrackingStatus(_ status: String?) -> String {
        switch status {
        case "on_track": return "Al día"
        case "behind": return "Atrasado"
        case "reached": return "¡Alcanzada!"
        case "no_target_date": return "Sin fecha límite"
        case "archived": return "Archivada"
        case "paused": return "Pausada"
        case "completed": return "Completada"
        default: return status ?? "Sin estado"
        }
    }

    private func formatPledgeState(_ state: String?) -> String {
        switch state {
        case "open": return "Abierto"
        case "matched": return "Coincidió"
        case "cancelled": return "Cancelado"
        case "expired": return "Vencido"
        default: return state ?? ""
        }
    }
}
