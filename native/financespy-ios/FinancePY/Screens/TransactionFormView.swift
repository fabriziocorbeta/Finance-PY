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
    @State private var date: Date = Date()
    @State private var categoryId: String = "" // Placeholder for now, categories fetched elsewhere normally
    @State private var merchantId: String = "" // Placeholder
    @State private var notes: String = ""

    @State private var categories: [CategoryRefDto] = []
    @State private var merchants: [MerchantRefDto] = []

    @State private var isSaving = false
    @State private var error: String? = nil

    // Approximate DEVICE location at Wallet-capture time (Android-only
    // capture) -- never the real merchant location. nil for any
    // transaction not captured that way, and always nil for a new one.
    @State private var locationLatitude: Double? = nil
    @State private var locationLongitude: Double? = nil
    @State private var locationDevice: String? = nil

    init(transactionToEdit: EntryEntity? = nil) {
        self.transactionToEdit = transactionToEdit
        if let tx = transactionToEdit {
            _accountId = State(initialValue: tx.accountId)
            _name = State(initialValue: tx.name)
            _locationLatitude = State(initialValue: tx.transaction?.latitude)
            _locationLongitude = State(initialValue: tx.transaction?.longitude)
            _locationDevice = State(initialValue: tx.transaction?.device)

            let amount = Formatters.centsToDouble(tx.transaction?.signedAmountCents ?? tx.amountCents, currency: tx.currency)
            _amountText = State(initialValue: String(abs(amount)))
            _nature = State(initialValue: amount < 0 ? "income" : "expense")

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            _date = State(initialValue: formatter.date(from: tx.date) ?? Date())

            // In a full implementation, categoryId/merchantId/notes would be populated from transaction details,
            // but EntryEntity/TransactionEntity only has categoryName/merchantName, so we skip IDs for edit mode here
            // unless fetched from API.
        } else {
            _date = State(initialValue: Date())
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

                    DatePicker("Fecha", selection: $date, displayedComponents: .date)
                }

                Section(header: Text("Clasificación")) {
                    // In a real app, these would be pickers populated from API/SwiftData
                    Picker("Categoría (opcional)", selection: $categoryId) {
                        Text("Ninguna").tag("")
                        ForEach(categories, id: \.id) { cat in
                            Text(cat.name).tag(cat.id)
                        }
                    }
                    Picker("Comerciante (opcional)", selection: $merchantId) {
                        Text("Ninguno").tag("")
                        ForEach(merchants, id: \.id) { merch in
                            Text(merch.name).tag(merch.id)
                        }
                    }
                }

                Section(header: Text("Notas")) {
                    TextField("Introduce una nota", text: $notes)
                }

                if let latitude = locationLatitude, let longitude = locationLongitude {
                    Section(header: Text("Ubicación aproximada (dispositivo)")) {
                        TransactionLocationMapView(
                            latitude: latitude,
                            longitude: longitude,
                            device: locationDevice
                        )
                    }
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
            .task {
                do {
                    categories = try await FinancePyApi.shared.fetchCategories()
                } catch {
                    print("Error fetching categories: \(error)")
                }
                do {
                    merchants = try await FinancePyApi.shared.fetchMerchants()
                } catch {
                    print("Error fetching merchants: \(error)")
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


        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let formattedDate = dateFormatter.string(from: date)

        isSaving = true
        error = nil

        do {
            if let tx = transactionToEdit, let transactionId = tx.transaction?.id {
                let body = UpdateTransactionBody(
                    accountId: accountId,
                    date: formattedDate,
                    amount: AnyStringAmount(wrappedValue: amountText),
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
                    date: formattedDate,
                    amount: AnyStringAmount(wrappedValue: amountText),
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
