import SwiftUI
import SwiftData

/// What the form had when it opened, so an update only sends what changed.
struct TransactionFormSnapshot: Equatable {
    var date: String
    var amountText: String
    var nature: String
    var notes: String
}

/// Builds the request bodies for POST/PATCH /api/v1/transactions. The server
/// takes an unsigned `amount` plus `nature` ("expense"/"income") and derives the
/// sign itself (expense positive, income negative in `entries.amount`).
enum TransactionFormPayload {
    static func createBody(
        accountId: String,
        date: String,
        amount: String,
        nature: String,
        name: String,
        notes: String,
        currency: String?,
        categoryId: String,
        merchantId: String
    ) -> CreateTransactionBody {
        CreateTransactionBody(
            accountId: accountId,
            date: date,
            amount: AnyStringAmount(wrappedValue: amount),
            nature: nature,
            name: name,
            notes: notes.isEmpty ? nil : notes,
            currency: currency,
            categoryId: categoryId.isEmpty ? nil : categoryId,
            merchantId: merchantId.isEmpty ? nil : merchantId,
            tagIds: nil
        )
    }

    /// `notesKnown` is false when only the local cache was available (detail
    /// fetch failed): notes are unknown then, so they are never sent.
    static func updateBody(
        original: TransactionFormSnapshot,
        notesKnown: Bool,
        date: String,
        amount: String,
        nature: String,
        name: String,
        notes: String,
        categoryId: String,
        merchantId: String
    ) -> UpdateTransactionBody {
        // The API rejects amount/date/nature on split parents, so only send them when edited.
        let amountChanged = amount != original.amountText || nature != original.nature
        return UpdateTransactionBody(
            accountId: nil, // the API ignores account_id on update
            date: date != original.date ? date : nil,
            amount: AnyStringAmount(wrappedValue: amountChanged ? amount : nil),
            nature: amountChanged ? nature : nil,
            name: name,
            notes: notesKnown && notes != original.notes ? notes : nil,
            currency: nil,
            categoryId: categoryId.isEmpty ? nil : categoryId,
            merchantId: merchantId.isEmpty ? nil : merchantId,
            tagIds: nil // not editable here; omitting keeps the server's tags
        )
    }
}

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
    @State private var categoryId: String = ""
    @State private var merchantId: String = ""
    @State private var notes: String = ""

    @State private var original = TransactionFormSnapshot(date: "", amountText: "", nature: "expense", notes: "")
    @State private var notesKnown = false
    @State private var isLoadingDetail = false

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

    private static let apiDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    init(transactionToEdit: EntryEntity? = nil) {
        self.transactionToEdit = transactionToEdit
        if let entry = transactionToEdit {
            let amount = Formatters.centsToAmountText(entry.amountCents, currency: entry.currency)
            // `classification` is the server's verdict; signed_amount_cents is positive for income.
            let nature = entry.classification == "income" ? "income" : "expense"
            _accountId = State(initialValue: entry.accountId)
            _name = State(initialValue: entry.name)
            _amountText = State(initialValue: amount)
            _nature = State(initialValue: nature)
            _date = State(initialValue: Self.apiDateFormatter.date(from: entry.date) ?? Date())
            _categoryId = State(initialValue: entry.transaction?.categoryId ?? "")
            _merchantId = State(initialValue: entry.transaction?.merchantId ?? "")
            _original = State(initialValue: TransactionFormSnapshot(date: entry.date, amountText: amount, nature: nature, notes: ""))
            _locationLatitude = State(initialValue: entry.transaction?.latitude)
            _locationLongitude = State(initialValue: entry.transaction?.longitude)
            _locationDevice = State(initialValue: entry.transaction?.device)
        }
    }

    private var isEditing: Bool { transactionToEdit != nil }

    private var selectedCurrency: String {
        if let entry = transactionToEdit { return entry.currency }
        return accounts.first(where: { $0.id == accountId })?.currency ?? "PYG"
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
                    // The API does not move a transaction between accounts on update.
                    .disabled(isEditing)

                    TextField("Descripción", text: $name)

                    TextField("Importe", text: $amountText)
                        .keyboardType(.decimalPad)

                    Picker("Tipo", selection: $nature) {
                        Text("Gasto").tag("expense")
                        Text("Ingreso").tag("income")
                    }
                    .pickerStyle(.segmented)

                    DatePicker("Fecha", selection: $date, displayedComponents: .date)
                }

                Section(header: Text("Clasificación")) {
                    Picker("Categoría (opcional)", selection: $categoryId) {
                        Text("Ninguna").tag("")
                        ForEach(categories, id: \.id) { cat in
                            Text(cat.name).tag(cat.id)
                        }
                    }
                    Picker("Comercio (opcional)", selection: $merchantId) {
                        Text("Ninguno").tag("")
                        ForEach(merchants, id: \.id) { merch in
                            Text(merch.name).tag(merch.id)
                        }
                    }
                }

                Section(header: Text("Notas")) {
                    TextField("Agregá una nota", text: $notes)
                        .disabled(isEditing && !notesKnown)
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
            .navigationTitle(isEditing ? "Editar transacción" : "Nueva transacción")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving || isLoadingDetail {
                        ProgressView()
                    } else {
                        Button("Guardar") {
                            Task { await saveTransaction() }
                        }
                    }
                }
            }
            .onAppear {
                if accountId.isEmpty, let first = accounts.first {
                    accountId = first.id
                }
            }
            .task {
                if let entry = transactionToEdit {
                    await loadDetail(id: entry.transaction?.id ?? entry.id)
                }
                if let fetched = try? await FinancePyApi.shared.fetchCategories() {
                    categories = fetched
                }
                if let fetched = try? await FinancePyApi.shared.fetchMerchants() {
                    merchants = fetched
                }
            }
        }
    }

    /// The local cache has no notes, so fetch the full transaction; if that fails
    /// the form still works from the cached fields, it just leaves notes untouched.
    private func loadDetail(id: String) async {
        isLoadingDetail = true
        defer { isLoadingDetail = false }
        guard let detail = try? await FinancePyApi.shared.fetchTransaction(id: id) else { return }

        let amount = Formatters.centsToAmountText(detail.amountCents, currency: detail.currency)
        let detailNature = detail.classification == "income" ? "income" : "expense"
        name = detail.name
        amountText = amount
        nature = detailNature
        date = Self.apiDateFormatter.date(from: detail.date) ?? date
        notes = detail.notes ?? ""
        categoryId = detail.category?.id ?? ""
        merchantId = detail.merchant?.id ?? ""
        original = TransactionFormSnapshot(date: detail.date, amountText: amount, nature: detailNature, notes: notes)
        notesKnown = true
    }

    private func saveTransaction() async {
        guard !accountId.isEmpty else {
            error = "Seleccioná una cuenta"
            return
        }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            error = "La descripción no puede estar vacía"
            return
        }
        guard let amount = Formatters.normalizedAmountInput(amountText, currency: selectedCurrency) else {
            error = "Ingresá un importe válido mayor a cero"
            return
        }

        let formattedDate = Self.apiDateFormatter.string(from: date)

        isSaving = true
        error = nil

        do {
            let saved: TransactionDetailDto
            if let entry = transactionToEdit {
                let body = TransactionFormPayload.updateBody(
                    original: original,
                    notesKnown: notesKnown,
                    date: formattedDate,
                    amount: amount,
                    nature: nature,
                    name: trimmedName,
                    notes: notes,
                    categoryId: categoryId,
                    merchantId: merchantId
                )
                saved = try await FinancePyApi.shared.updateTransaction(id: entry.transaction?.id ?? entry.id, body: body)
            } else {
                let body = TransactionFormPayload.createBody(
                    accountId: accountId,
                    date: formattedDate,
                    amount: amount,
                    nature: nature,
                    name: trimmedName,
                    notes: notes,
                    // Without it the API falls back to the family currency, wrong for a USD account.
                    currency: accounts.first(where: { $0.id == accountId })?.currency,
                    categoryId: categoryId,
                    merchantId: merchantId
                )
                saved = try await FinancePyApi.shared.createTransaction(body: body)
            }
            upsertLocal(saved)
            dismiss()
        } catch {
            self.error = Self.message(for: error)
            isSaving = false
        }
    }

    /// Mirrors SyncEngine's upsert so the Transacciones list (a @Query) shows the change right away.
    private func upsertLocal(_ dto: TransactionDetailDto) {
        let id = dto.id
        let existing = try? modelContext.fetch(FetchDescriptor<EntryEntity>(predicate: #Predicate { $0.id == id })).first

        let entry = existing ?? EntryEntity(
            id: dto.id,
            accountId: dto.account.id,
            date: dto.date,
            name: dto.name,
            amountCents: dto.amountCents,
            currency: dto.currency,
            classification: dto.classification,
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt
        )
        entry.accountId = dto.account.id
        entry.date = dto.date
        entry.name = dto.name
        entry.amountCents = dto.amountCents
        entry.currency = dto.currency
        entry.classification = dto.classification
        entry.updatedAt = dto.updatedAt

        let tx = entry.transaction ?? TransactionEntity(id: dto.id, entryId: dto.id, signedAmountCents: dto.signedAmountCents)
        tx.signedAmountCents = dto.signedAmountCents
        tx.categoryId = dto.category?.id
        tx.categoryName = dto.category?.name
        tx.categoryColor = dto.category?.color
        tx.categoryIcon = dto.category?.icon
        tx.merchantId = dto.merchant?.id
        tx.merchantName = dto.merchant?.name
        tx.latitude = dto.location?.latitude
        tx.longitude = dto.location?.longitude
        tx.device = dto.location?.device

        if existing == nil {
            modelContext.insert(entry)
        }
        if entry.transaction == nil {
            modelContext.insert(tx)
            tx.entry = entry
            entry.transaction = tx
        }
        try? modelContext.save()
    }

    /// Surfaces the API's validation message ("Name can't be blank", split guards)
    /// instead of the raw "HTTP error 422: {json}".
    static func message(for error: Error) -> String {
        if case NetworkError.httpError(_, let body?) = error,
           let data = body.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let errors = json["errors"] as? [String], !errors.isEmpty {
                return errors.joined(separator: "\n")
            }
            if let message = json["message"] as? String {
                return message
            }
        }
        return error.localizedDescription
    }
}
