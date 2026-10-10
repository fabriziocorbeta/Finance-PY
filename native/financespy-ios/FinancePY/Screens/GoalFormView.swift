import SwiftUI

struct GoalFormView: View {
    let goalId: String?
    @Environment(\.presentationMode) var presentationMode

    @State private var name: String = ""
    @State private var targetAmount: String = ""
    @State private var currency: String = "USD"
    @State private var targetDate: Date? = nil
    @State private var color: String = ""
    @State private var icon: String = ""
    @State private var notes: String = ""

    @State private var selectedAccountIds: Set<String> = []
    @State private var allocations: [String: String] = [:]

    @State private var availableAccounts: [AccountDto] = []

    @State private var isLoading = false
    @State private var isSaving = false
    @State private var errorMessage: String? = nil

    @State private var showDatePicker = false

    init(goalId: String? = nil) {
        self.goalId = goalId
    }

    var body: some View {
        Form {
            if isLoading {
                ProgressView("Cargando...")
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                Section(header: Text("Información General")) {
                    TextField("Nombre de la meta", text: $name)

                    HStack {
                        Text(currency)
                            .foregroundColor(.secondary)
                        TextField("Monto objetivo", text: $targetAmount)
                            .keyboardType(.decimalPad)
                    }

                    Picker("Moneda", selection: $currency) {
                        Text("USD").tag("USD")
                        Text("PYG").tag("PYG")
                        // Add more if needed
                    }

                    HStack {
                        Text("Fecha objetivo (opcional)")
                        Spacer()
                        if let date = targetDate {
                            Text(formatDate(date))
                                .foregroundColor(.primary)
                                .onTapGesture {
                                    showDatePicker.toggle()
                                }
                            Button(action: { targetDate = nil }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Button("Seleccionar") {
                                targetDate = Date()
                                showDatePicker = true
                            }
                        }
                    }

                    if showDatePicker {
                        DatePicker("", selection: Binding(
                            get: { targetDate ?? Date() },
                            set: { targetDate = $0 }
                        ), displayedComponents: .date)
                        .datePickerStyle(.graphical)
                    }

                    TextField("Notas", text: $notes)
                }

                Section(header: Text("Cuentas Vinculadas"), footer: Text("Seleccioná las cuentas de donde se extraerán los fondos para esta meta.")) {
                    if availableAccounts.isEmpty {
                        Text("No hay cuentas disponibles.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(availableAccounts, id: \.id) { account in
                            VStack(alignment: .leading, spacing: 8) {
                                Toggle(isOn: Binding(
                                    get: { selectedAccountIds.contains(account.id) },
                                    set: { isSelected in
                                        if isSelected {
                                            selectedAccountIds.insert(account.id)
                                        } else {
                                            selectedAccountIds.remove(account.id)
                                            allocations.removeValue(forKey: account.id)
                                        }
                                    }
                                )) {
                                    Text(account.name)
                                }

                                if selectedAccountIds.contains(account.id) {
                                    HStack {
                                        Text("Monto fijo (opcional):")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        TextField("Monto", text: Binding(
                                            get: { allocations[account.id] ?? "" },
                                            set: { allocations[account.id] = $0 }
                                        ))
                                        .keyboardType(.decimalPad)
                                        .font(.caption)
                                    }
                                    .padding(.leading, 32)
                                }
                            }
                        }
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }

                Section {
                    Button(action: saveGoal) {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Guardar Meta")
                                .frame(maxWidth: .infinity, alignment: .center)
                                .foregroundColor(.white)
                        }
                    }
                    .listRowBackground(Color.accentColor)
                    .disabled(isSaving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || targetAmount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .navigationTitle(goalId == nil ? "Nueva Meta" : "Editar Meta")
        .task {
            await loadData()
        }
    }

    private func loadData() async {
        isLoading = true
        errorMessage = nil

        do {
            availableAccounts = try await FinancePyApi.shared.fetchAllAccounts()

            if let id = goalId {
                let goal = try await FinancePyApi.shared.fetchGoal(id: id)

                name = goal.name
                targetAmount = goal.targetAmount ?? ""
                currency = goal.currency ?? "USD"
                notes = goal.notes ?? ""

                if let dateStr = goal.targetDate {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd"
                    targetDate = formatter.date(from: dateStr)
                }

                if let accIds = goal.accountIds {
                    selectedAccountIds = Set(accIds)
                }

                if let alls = goal.allocations {
                    for (k, v) in alls {
                        if let val = v {
                            allocations[k] = val
                        }
                    }
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func saveGoal() {
        guard let amount = Double(targetAmount), amount > 0 else {
            errorMessage = "El monto objetivo debe ser mayor a cero."
            return
        }

        if goalId == nil && selectedAccountIds.isEmpty {
            errorMessage = "Seleccioná al menos una cuenta vinculada."
            return
        }

        Task {
            isSaving = true
            errorMessage = nil

            var dateStr: String? = nil
            if let date = targetDate {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                dateStr = formatter.string(from: date)
            }

            let accountIdsList = Array(selectedAccountIds)
            var allocationsMap: [String: String]? = nil

            let filteredAllocations = allocations.filter { selectedAccountIds.contains($0.key) && !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            if !filteredAllocations.isEmpty {
                allocationsMap = filteredAllocations
            }

            var goalAccountsAttrs: [GoalAccountAttributeDto]? = nil
            if !selectedAccountIds.isEmpty {
                goalAccountsAttrs = selectedAccountIds.map { accId in
                    let alloc = allocations[accId]?.trimmingCharacters(in: .whitespacesAndNewlines)
                    return GoalAccountAttributeDto(accountId: accId, allocatedAmount: (alloc?.isEmpty == false) ? alloc : nil)
                }
            }

            do {
                if let id = goalId {
                    let body = UpdateGoalBody(
                        name: name,
                        targetAmount: targetAmount,
                        currency: currency,
                        targetDate: dateStr,
                        color: nil,
                        icon: nil,
                        notes: notes.isEmpty ? nil : notes,
                        state: nil,
                        accountIds: accountIdsList,
                        allocations: allocationsMap,
                        goalAccountsAttributes: goalAccountsAttrs
                    )
                    _ = try await FinancePyApi.shared.updateGoal(id: id, body: body)
                } else {
                    let body = CreateGoalBody(
                        name: name,
                        targetAmount: targetAmount,
                        currency: currency,
                        targetDate: dateStr,
                        color: nil,
                        icon: nil,
                        notes: notes.isEmpty ? nil : notes,
                        accountIds: accountIdsList,
                        allocations: allocationsMap,
                        goalAccountsAttributes: goalAccountsAttrs
                    )
                    _ = try await FinancePyApi.shared.createGoal(body: body)
                }

                presentationMode.wrappedValue.dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
