import SwiftUI
import SwiftData

struct ReceivableFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.presentationMode) var presentationMode

    var receivableId: String? = nil

    @State private var name: String = ""
    @State private var totalAmount: String = ""
    @State private var balance: String = ""
    @State private var installmentCount: String = ""
    @State private var dueDay: String = ""
    @State private var currency: String = "PYG"
    @State private var notes: String = ""

    @State private var isSaving = false
    @State private var error: String? = nil

    private var isEditing: Bool { receivableId != nil }

    var body: some View {
        Form {
            Section(header: Text(isEditing ? "Editar cuenta a cobrar" : "Nueva cuenta a cobrar")) {
                TextField("Nombre de la cuenta", text: $name)

                TextField("Monto total", text: $totalAmount)
                    .keyboardType(.decimalPad)

                TextField(isEditing ? "Saldo actual" : "Saldo inicial (opcional, por defecto monto total)", text: $balance)
                    .keyboardType(.decimalPad)

                TextField("Cantidad de cuotas (opcional)", text: $installmentCount)
                    .keyboardType(.numberPad)

                TextField("Día de pago (1-31, opcional)", text: $dueDay)
                    .keyboardType(.numberPad)

                TextField("Moneda (ej. PYG, USD)", text: $currency)
                    .autocapitalization(.allCharacters)

                TextField("Notas (opcional)", text: $notes)
            }

            if let error = error {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }

            Section {
                Button(action: saveReceivable) {
                    Text(isSaving ? "Guardando..." : "Guardar")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .disabled(isSaving)
            }
        }
        .navigationTitle(isEditing ? "Editar" : "Nuevo")
        .task {
            if let id = receivableId {
                loadExistingReceivable(id: id)
            }
        }
    }

    private func loadExistingReceivable(id: String) {
        let descriptor = FetchDescriptor<ReceivableEntity>(predicate: #Predicate { $0.id == id })
        if let existing = try? modelContext.fetch(descriptor).first {
            name = existing.name
            totalAmount = String(existing.totalAmount)
            balance = String(existing.balance)
            installmentCount = existing.installmentCount.map(String.init) ?? ""
            dueDay = existing.dueDay.map(String.init) ?? ""
            currency = existing.currency
            notes = existing.notes ?? ""
        }
    }

    private func saveReceivable() {
        if isSaving { return }

        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            error = "El nombre de la cuenta es obligatorio"
            return
        }

        guard let parsedTotalAmount = Double(totalAmount), parsedTotalAmount > 0 else {
            error = "El monto total debe ser un número mayor a 0"
            return
        }

        let parsedBalance: Double? = !balance.isEmpty ? Double(balance) : parsedTotalAmount
        guard parsedBalance != nil else {
            error = "El saldo debe ser un número válido"
            return
        }

        let parsedInstallmentCount: Int? = !installmentCount.isEmpty ? Int(installmentCount) : nil
        if !installmentCount.isEmpty && parsedInstallmentCount == nil {
            error = "La cantidad de cuotas debe ser un número entero válido"
            return
        }

        let parsedDueDay: Int? = !dueDay.isEmpty ? Int(dueDay) : nil
        if let day = parsedDueDay, !(1...31).contains(day) {
            error = "El día de pago debe ser entre 1 y 31"
            return
        }

        isSaving = true
        error = nil

        Task {
            do {
                if let id = receivableId {
                    let updateBody = UpdateReceivableBody(
                        name: name,
                        totalAmount: parsedTotalAmount,
                        balance: parsedBalance,
                        installmentCount: parsedInstallmentCount,
                        dueDay: parsedDueDay,
                        currency: currency,
                        notes: notes.isEmpty ? nil : notes
                    )

                    let dto = try await FinancePyApi.shared.updateReceivable(id: id, updateBody)
                    upsertLocally(dto)

                } else {
                    let createBody = CreateReceivableBody(
                        name: name,
                        totalAmount: parsedTotalAmount,
                        balance: parsedBalance,
                        installmentCount: parsedInstallmentCount,
                        dueDay: parsedDueDay,
                        currency: currency,
                        notes: notes.isEmpty ? nil : notes
                    )

                    let dto = try await FinancePyApi.shared.createReceivable(createBody)
                    upsertLocally(dto)
                }

                isSaving = false
                presentationMode.wrappedValue.dismiss()
            } catch {
                isSaving = false
                self.error = error.localizedDescription
            }
        }
    }

    private func upsertLocally(_ dto: ReceivableDto) {
        let installmentScheduleData: Data? = {
            if let schedule = dto.installmentSchedule {
                let encoder = JSONEncoder()
                encoder.keyEncodingStrategy = .convertToSnakeCase
                return try? encoder.encode(schedule)
            }
            return nil
        }()

        let id = dto.id
        let descriptor = FetchDescriptor<ReceivableEntity>(predicate: #Predicate { $0.id == id })
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.accountId = dto.accountId
            existing.name = dto.name ?? "(sin nombre)"
            existing.totalAmount = dto.totalAmount ?? 0.0
            existing.balance = dto.balance ?? 0.0
            existing.balanceCents = dto.balanceCents ?? 0
            existing.originalBalance = dto.originalBalance ?? 0.0
            existing.originalBalanceCents = dto.originalBalanceCents ?? 0
            existing.paidAmount = dto.paidAmount ?? 0.0
            existing.paidAmountCents = dto.paidAmountCents ?? 0
            existing.percentPaid = dto.percentPaid ?? 0.0
            existing.installmentCount = dto.installmentCount
            existing.dueDay = dto.dueDay
            existing.currency = dto.currency ?? "PYG"
            existing.notes = dto.notes
            existing.updatedAt = dto.updatedAt ?? ""
            existing.installmentScheduleData = installmentScheduleData
        } else {
            let newEntity = ReceivableEntity(
                id: dto.id,
                accountId: dto.accountId,
                name: dto.name ?? "(sin nombre)",
                totalAmount: dto.totalAmount ?? 0.0,
                balance: dto.balance ?? 0.0,
                balanceCents: dto.balanceCents ?? 0,
                originalBalance: dto.originalBalance ?? 0.0,
                originalBalanceCents: dto.originalBalanceCents ?? 0,
                paidAmount: dto.paidAmount ?? 0.0,
                paidAmountCents: dto.paidAmountCents ?? 0,
                percentPaid: dto.percentPaid ?? 0.0,
                installmentCount: dto.installmentCount,
                dueDay: dto.dueDay,
                currency: dto.currency ?? "PYG",
                notes: dto.notes,
                updatedAt: dto.updatedAt ?? "",
                installmentScheduleData: installmentScheduleData
            )
            modelContext.insert(newEntity)
        }
        try? modelContext.save()
    }
}
