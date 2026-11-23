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

    @ObservedObject private var locationManager = LocationCaptureManager.shared
    @State private var locationLatitude: Double? = nil
    @State private var locationLongitude: Double? = nil
    @State private var locationDevice: String? = nil

    // Invoice photo state
    @State private var hasRemoteInvoicePhoto: Bool = false
    @State private var remoteInvoiceFilename: String? = nil
    @State private var invoicePhotoData: Data? = nil
    @State private var pendingPhotoUpload: (data: Data, fileName: String)? = nil
    @State private var isLoadingPhoto: Bool = false
    @State private var isUploadingPhoto: Bool = false

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

                Section(header: Text("Foto de factura")) {
                    InvoicePhotoSectionView(
                        title: "Comprobante / Factura",
                        hasRemotePhoto: hasRemoteInvoicePhoto,
                        remoteFilename: remoteInvoiceFilename,
                        imageData: invoicePhotoData,
                        isLoading: isLoadingPhoto,
                        isUploading: isUploadingPhoto,
                        onPickImage: { data, fileName in
                            invoicePhotoData = data
                            pendingPhotoUpload = (data, fileName)
                        },
                        onDeletePhoto: {
                            Task { await deleteInvoicePhoto() }
                        }
                    )
                }

                if nature == "expense" || (locationLatitude != nil && locationLongitude != nil) {
                    Section(header: Text("Ubicación del gasto")) {
                        if let latitude = locationLatitude, let longitude = locationLongitude {
                            TransactionLocationMapView(
                                latitude: latitude,
                                longitude: longitude,
                                device: locationDevice
                            )
                            Button(role: .destructive) {
                                locationLatitude = nil
                                locationLongitude = nil
                                locationDevice = nil
                            } label: {
                                Label("Quitar ubicación", systemImage: "location.slash")
                            }
                        } else {
                            Button {
                                Task { await captureCurrentLocation() }
                            } label: {
                                HStack {
                                    Label(
                                        locationManager.isCapturing ? "Obteniendo ubicación..." : "Capturar ubicación actual",
                                        systemImage: "location.fill"
                                    )
                                    if locationManager.isCapturing {
                                        Spacer()
                                        ProgressView()
                                    }
                                }
                            }
                            .disabled(locationManager.isCapturing)
                        }
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
                    #if DEBUG
                    print("Error fetching categories: \(error)")
                    #endif
                }
                do {
                    merchants = try await FinancePyApi.shared.fetchMerchants()
                } catch {
                    #if DEBUG
                    print("Error fetching merchants: \(error)")
                    #endif
                }
                if transactionToEdit == nil,
                   nature == "expense",
                   locationManager.isPreciseLocationEnabled,
                   locationLatitude == nil {
                    await captureCurrentLocation()
                }
                if let txId = transactionToEdit?.transaction?.id {
                    await loadExistingInvoicePhoto(transactionId: txId)
                }
            }
        }
    }

    private func captureCurrentLocation() async {
        if let coord = await locationManager.requestCurrentLocation() {
            locationLatitude = coord.latitude
            locationLongitude = coord.longitude
            locationDevice = "iPhone"
        }
    }

    private func loadExistingInvoicePhoto(transactionId: String) async {
        isLoadingPhoto = true
        defer { isLoadingPhoto = false }
        if let data = try? await FinancePyApi.shared.downloadTransactionInvoicePhoto(transactionId: transactionId),
           !data.isEmpty {
            invoicePhotoData = data
            hasRemoteInvoicePhoto = true
        }
    }

    private func deleteInvoicePhoto() async {
        pendingPhotoUpload = nil
        invoicePhotoData = nil
        guard hasRemoteInvoicePhoto, let txId = transactionToEdit?.transaction?.id else {
            hasRemoteInvoicePhoto = false
            return
        }
        isUploadingPhoto = true
        defer { isUploadingPhoto = false }
        do {
            _ = try await FinancePyApi.shared.deleteTransactionInvoicePhoto(transactionId: txId)
            hasRemoteInvoicePhoto = false
            remoteInvoiceFilename = nil
        } catch {
            if NetworkMonitor.isConnectivityError(error) {
                OfflineOutbox.shared.enqueue(.deleteInvoicePhoto(entityType: .transaction, entityId: txId))
                hasRemoteInvoicePhoto = false
                remoteInvoiceFilename = nil
            } else {
                self.error = error.localizedDescription
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
            let savedTransactionId: String
            if let tx = transactionToEdit, let transactionId = tx.transaction?.id {
                let body = UpdateTransactionBody(
                    accountId: accountId,
                    date: formattedDate,
                    amount: amountText,
                    nature: nature,
                    name: name,
                    notes: notes.isEmpty ? nil : notes,
                    currency: nil,
                    categoryId: categoryId.isEmpty ? nil : categoryId,
                    merchantId: merchantId.isEmpty ? nil : merchantId,
                    tagIds: nil,
                    latitude: locationLatitude,
                    longitude: locationLongitude
                )

                let updated = try await FinancePyApi.shared.updateTransaction(id: transactionId, body: body)
                updateEntity(updated: updated)
                savedTransactionId = updated.id
            } else {
                let body = CreateTransactionBody(
                    accountId: accountId,
                    date: formattedDate,
                    amount: amountText,
                    nature: nature,
                    name: name,
                    notes: notes.isEmpty ? nil : notes,
                    currency: nil,
                    categoryId: categoryId.isEmpty ? nil : categoryId,
                    merchantId: merchantId.isEmpty ? nil : merchantId,
                    tagIds: nil,
                    latitude: locationLatitude,
                    longitude: locationLongitude
                )

                let created = try await FinancePyApi.shared.createTransaction(body: body)
                updateEntity(updated: created)
                savedTransactionId = created.id
            }

            if let pending = pendingPhotoUpload {
                isUploadingPhoto = true
                do {
                    _ = try await FinancePyApi.shared.uploadTransactionInvoicePhoto(
                        transactionId: savedTransactionId,
                        fileData: pending.data,
                        fileName: pending.fileName
                    )
                } catch {
                    if NetworkMonitor.isConnectivityError(error) {
                        let blobId = OfflineBlobStore.shared.saveBlob(pending.data)
                        OfflineOutbox.shared.enqueue(.uploadInvoicePhoto(
                            entityType: .transaction,
                            entityId: savedTransactionId,
                            blobId: blobId,
                            fileName: pending.fileName,
                            mimeType: "image/jpeg"
                        ))
                    } else {
                        self.error = error.localizedDescription
                        isUploadingPhoto = false
                        isSaving = false
                        return
                    }
                }
                isUploadingPhoto = false
            }

            dismiss()
        } catch {
            if NetworkMonitor.isConnectivityError(error) {
                if let tx = transactionToEdit, let transactionId = tx.transaction?.id {
                    let body = UpdateTransactionBody(
                        accountId: accountId,
                        date: formattedDate,
                        amount: amountText,
                        nature: nature,
                        name: name,
                        notes: notes.isEmpty ? nil : notes,
                        currency: nil,
                        categoryId: categoryId.isEmpty ? nil : categoryId,
                        merchantId: merchantId.isEmpty ? nil : merchantId,
                        tagIds: nil,
                        latitude: locationLatitude,
                        longitude: locationLongitude
                    )
                    OfflineOutbox.shared.enqueue(.updateTransaction(id: transactionId, body: body))
                    if let pending = pendingPhotoUpload {
                        let blobId = OfflineBlobStore.shared.saveBlob(pending.data)
                        OfflineOutbox.shared.enqueue(.uploadInvoicePhoto(
                            entityType: .transaction,
                            entityId: transactionId,
                            blobId: blobId,
                            fileName: pending.fileName,
                            mimeType: "image/jpeg"
                        ))
                    }
                } else {
                    let body = CreateTransactionBody(
                        accountId: accountId,
                        date: formattedDate,
                        amount: amountText,
                        nature: nature,
                        name: name,
                        notes: notes.isEmpty ? nil : notes,
                        currency: nil,
                        categoryId: categoryId.isEmpty ? nil : categoryId,
                        merchantId: merchantId.isEmpty ? nil : merchantId,
                        tagIds: nil,
                        latitude: locationLatitude,
                        longitude: locationLongitude
                    )
                    OfflineOutbox.shared.enqueue(.createTransaction(body))
                }
                dismiss()
                return
            }
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
