import SwiftUI
import SwiftData

struct TransactionFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // Existing transaction to edit, if any
    var transactionToEdit: EntryEntity? = nil

    @Query(sort: \AccountEntity.name) private var accounts: [AccountEntity]

    @State private var accountId: String = ""
    @State private var name: String = ""
    @State private var amountText: String = ""
    @State private var nature: String = "expense"
    @State private var date: String = ""
    @State private var categoryId: String = "" // Placeholder for now, categories fetched elsewhere normally
    @State private var merchantId: String = "" // Placeholder
    @State private var notes: String = ""

    @State private var isSaving = false
    @State private var error: String? = nil

    init(transactionToEdit: EntryEntity? = nil) {
        self.transactionToEdit = transactionToEdit
        if let tx = transactionToEdit {
            _accountId = State(initialValue: tx.accountId)
            _name = State(initialValue: tx.name)

            let amount = Double(tx.transaction?.signedAmountCents ?? tx.amountCents) / 100.0
            _amountText = State(initialValue: String(abs(amount)))
            _nature = State(initialValue: amount < 0 ? "income" : "expense")

            _date = State(initialValue: tx.date)

            // In a full implementation, categoryId/merchantId/notes would be populated from transaction details,
            // but EntryEntity/TransactionEntity only has categoryName/merchantName, so we skip IDs for edit mode here
            // unless fetched from API.
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            _date = State(initialValue: formatter.string(from: Date()))
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Detalles principales")) {
                    Picker("Cuenta", selection: $accountId) {
                        Text("Seleccionar cuenta").tag("")
                        ForEach(accounts) { account in
                            Text(account.name).tag(account.id)
                        }
                    }

                    TextField("Descripción", text: $name)

                    HStack {
                        TextField("Importe", text: $amountText)
                            .keyboardType(.decimalPad)

                        Picker("Tipo", selection: $nature) {
                            Text("Ingreso").tag("income")
                            Text("Gasto").tag("expense")
                        }
                        .pickerStyle(.segmented)
                    }

                    TextField("Fecha (AAAA-MM-DD)", text: $date)
                        .keyboardType(.numbersAndPunctuation)
                }

                Section(header: Text("Clasificación")) {
                    // In a real app, these would be pickers populated from API/SwiftData
                    TextField("ID de Categoría (opcional)", text: $categoryId)
                    TextField("ID de Comerciante (opcional)", text: $merchantId)
                }

                Section(header: Text("Notas")) {
                    TextField("Introduce una nota", text: $notes)
                }

                if let error = error {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle(transactionToEdit == nil ? "Nueva Transacción" : "Editar Transacción")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        Task { await saveTransaction() }
                    }
                    .disabled(isSaving)
                }
            }
            .onAppear {
                if accountId.isEmpty, let first = accounts.first {
                    accountId = first.id
                }
            }
        }
    }

    private func saveTransaction() async {
        guard !accountId.isEmpty else {
            error = "Selecciona una cuenta"
            return
        }
        guard !name.isEmpty else {
            error = "Introduce una descripción"
            return
        }
        guard Double(amountText) != nil else {
            error = "Introduce un importe válido"
            return
        }
        guard !date.isEmpty else { // Ideally validate AAAA-MM-DD format
            error = "Introduce una fecha"
            return
        }

        isSaving = true
        error = nil

        do {
            if let tx = transactionToEdit, let transactionId = tx.transaction?.id {
                let body = UpdateTransactionBody(
                    accountId: accountId,
                    date: date,
                    amount: amountText,
                    nature: nature,
                    name: name,
                    notes: notes.isEmpty ? nil : notes,
                    currency: nil,
                    categoryId: categoryId.isEmpty ? nil : categoryId,
                    merchantId: merchantId.isEmpty ? nil : merchantId,
                    tagIds: nil
                )

                let updated = try await FinancePyApi.shared.updateTransaction(id: transactionId, body: body)
                updateEntity(updated: updated)
            } else {
                let body = CreateTransactionBody(
                    accountId: accountId,
                    date: date,
                    amount: amountText,
                    nature: nature,
                    name: name,
                    notes: notes.isEmpty ? nil : notes,
                    currency: nil, // API defaults to family currency if omitted
                    categoryId: categoryId.isEmpty ? nil : categoryId,
                    merchantId: merchantId.isEmpty ? nil : merchantId,
                    tagIds: nil
                )

                let created = try await FinancePyApi.shared.createTransaction(body: body)
                updateEntity(updated: created)
            }
            dismiss()
        } catch {
            self.error = error.localizedDescription
            isSaving = false
        }
    }

    private func updateEntity(updated: TransactionDetailDto) {
        // Upsert into SwiftData
        // Ideally we would sync the transaction into SwiftData so it shows up in TransactionsView.
        // We do a simple insert of EntryEntity + TransactionEntity here.
        // SyncEngine is the proper place, but for immediate UI response:

        let txEntity = TransactionEntity(
            id: updated.id,
            entryId: updated.id,
            signedAmountCents: updated.signedAmountCents,
            categoryName: updated.category?.name,
            merchantName: updated.merchant?.name
        )

        let entry = EntryEntity(
            id: updated.id, // Usually entry id != transaction id in API, but for simplicity assuming we need to store it
            accountId: updated.account.id,
            date: updated.date,
            name: updated.name,
            amountCents: updated.amountCents,
            currency: updated.currency,
            classification: updated.classification,
            createdAt: updated.createdAt,
            updatedAt: updated.updatedAt,
            transaction: txEntity
        )
        txEntity.entry = entry

        modelContext.insert(entry)
        try? modelContext.save()
    }
}
