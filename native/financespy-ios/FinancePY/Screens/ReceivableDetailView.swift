import SwiftUI
import SwiftData

struct ReceivableDetailView: View {
    let receivableId: String
    @Environment(\.modelContext) private var modelContext
    @Environment(\.presentationMode) var presentationMode

    @Query private var receivables: [ReceivableEntity]

    init(receivableId: String) {
        self.receivableId = receivableId
        let predicate = #Predicate<ReceivableEntity> { $0.id == receivableId }
        _receivables = Query(filter: predicate)
    }

    @State private var isDeleting = false
    @State private var deleteError: String? = nil

    @State private var showPaymentDialog = false
    @State private var paymentAccounts: [AccountDto] = []
    @State private var paymentFromAccountId: String = ""
    @State private var paymentAmount: String = ""
    @State private var paymentDate: String = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }()
    @State private var isRegisteringPayment = false
    @State private var paymentError: String? = nil

    var body: some View {
        if let receivable = receivables.first {
            ScrollView {
                VStack(spacing: 20) {
                    // Main Card
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Detalles de la cuenta")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        DetailRow(label: "Monto total", value: formatMoney(amount: receivable.totalAmount, currency: receivable.currency))
                        DetailRow(label: "Saldo actual", value: formatMoney(amount: receivable.balance, currency: receivable.currency))

                        let paidAmount = receivable.originalBalance > 0 ? (receivable.originalBalance - receivable.balance) : 0.0
                        DetailRow(label: "Cobrado", value: "\(formatMoney(amount: paidAmount, currency: receivable.currency)) (\(Int(receivable.percentPaid))%)")

                        if let count = receivable.installmentCount {
                            DetailRow(label: "Cantidad de cuotas", value: "\(count)")
                        }
                        if let day = receivable.dueDay {
                            DetailRow(label: "Día de pago", value: "\(day)")
                        }
                        if let notes = receivable.notes, !notes.isEmpty {
                            DetailRow(label: "Notas", value: notes)
                        }

                        VStack(spacing: 12) {
                            if receivable.balance > 0.0 {
                                Button(action: openPaymentDialog) {
                                    Text("Registrar pago")
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                            }

                            NavigationLink(destination: ReceivableFormView(receivableId: receivable.id)) {
                                Text("Editar")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.gray.opacity(0.2))
                                    .foregroundColor(.primary)
                                    .cornerRadius(8)
                            }

                            Button(action: deleteReceivable) {
                                Text(isDeleting ? "Borrando..." : "Borrar")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.red.opacity(0.1))
                                    .foregroundColor(.red)
                                    .cornerRadius(8)
                            }
                            .disabled(isDeleting)

                            if let error = deleteError {
                                Text(error)
                                    .foregroundColor(.red)
                                    .font(.caption)
                            }
                        }
                        .padding(.top, 8)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    // Installment Schedule Card
                    if let schedule = receivable.installmentSchedule, !schedule.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Cronograma de cuotas")
                                .font(.headline)

                            ForEach(schedule) { installment in
                                InstallmentRowView(installment: installment, currency: receivable.currency)
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle(receivable.name)
            .sheet(isPresented: $showPaymentDialog) {
                PaymentDialogView(
                    accounts: paymentAccounts,
                    selectedAccountId: $paymentFromAccountId,
                    amount: $paymentAmount,
                    date: $paymentDate,
                    isSaving: isRegisteringPayment,
                    error: paymentError,
                    onConfirm: {
                        registerPayment(receivableAccountId: receivable.accountId)
                    },
                    onDismiss: {
                        showPaymentDialog = false
                    }
                )
            }
        } else {
            Text("Cuenta no encontrada")
        }
    }

    private func deleteReceivable() {
        guard let receivable = receivables.first else { return }
        isDeleting = true
        deleteError = nil

        Task {
            do {
                try await FinancePyApi.shared.deleteReceivable(id: receivable.id)
                modelContext.delete(receivable)
                try modelContext.save()
                isDeleting = false
                presentationMode.wrappedValue.dismiss()
            } catch {
                isDeleting = false
                deleteError = "Error al borrar: \(error.localizedDescription)"
            }
        }
    }

    private func openPaymentDialog() {
        showPaymentDialog = true
        paymentError = nil
        Task {
            do {
                let allAccounts = try await FinancePyApi.shared.fetchAllAccounts()
                paymentAccounts = allAccounts.filter { $0.accountType == "Depository" && $0.status == "active" }
                if paymentFromAccountId.isEmpty {
                    paymentFromAccountId = paymentAccounts.first?.id ?? ""
                }
            } catch {
                paymentError = "No se pudieron cargar las cuentas"
            }
        }
    }

    private func registerPayment(receivableAccountId: String?) {
        guard let toAccountId = receivableAccountId,
              let amountDouble = Double(paymentAmount), amountDouble > 0,
              !paymentFromAccountId.isEmpty else {
            paymentError = "Completá cuenta e importe válido"
            return
        }

        isRegisteringPayment = true
        paymentError = nil

        Task {
            do {
                let transfer = CreateTransferBody(
                    fromAccountId: paymentFromAccountId,
                    toAccountId: toAccountId,
                    amount: amountDouble,
                    date: paymentDate
                )
                try await FinancePyApi.shared.createTransfer(transfer)
                isRegisteringPayment = false
                showPaymentDialog = false
                paymentAmount = ""
                // Triggers a list refresh when returning or could manually update here
            } catch {
                isRegisteringPayment = false
                paymentError = "No se pudo registrar el pago: \(error.localizedDescription)"
            }
        }
    }

    private func formatMoney(amount: Double, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: amount)) ?? "\(currency) \(amount)"
    }
}

struct InstallmentRowView: View {
    let installment: InstallmentDto
    let currency: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Cuota \(installment.number)")
                    .font(.body)

                let dateInfo = "Vence: \(installment.dueDate)" + (installment.paidAt != nil ? " • Pagada: \(installment.paidAt!)" : "")
                Text(dateInfo)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                let amountText = installment.status == "partial"
                    ? "\(formatMoney(amount: installment.paidAmount, currency: currency)) / \(formatMoney(amount: installment.amount, currency: currency))"
                    : formatMoney(amount: installment.amount, currency: currency)

                Text(amountText)
                    .font(.body)

                Text(statusText)
                    .font(.caption)
                    .foregroundColor(statusColor)
            }
        }
        .padding(.vertical, 4)
    }

    private var statusText: String {
        switch installment.status {
        case "paid": return "Pagada"
        case "partial": return "Parcial"
        case "overdue": return "Vencida"
        default: return "Pendiente"
        }
    }

    private var statusColor: Color {
        switch installment.status {
        case "paid": return .green
        case "partial": return .orange
        case "overdue": return .red
        default: return .secondary
        }
    }

    private func formatMoney(amount: Double, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: amount)) ?? "\(currency) \(amount)"
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

struct PaymentDialogView: View {
    let accounts: [AccountDto]
    @Binding var selectedAccountId: String
    @Binding var amount: String
    @Binding var date: String
    let isSaving: Bool
    let error: String?
    let onConfirm: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Registrar pago")) {
                    Picker("Cuenta de origen", selection: $selectedAccountId) {
                        if accounts.isEmpty {
                            Text("Cargando cuentas...").tag("")
                        } else {
                            ForEach(accounts, id: \.id) { account in
                                Text(account.name).tag(account.id)
                            }
                        }
                    }

                    TextField("Importe", text: $amount)
                        .keyboardType(.decimalPad)

                    TextField("Fecha (AAAA-MM-DD)", text: $date)
                }

                if let error = error {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationBarItems(
                leading: Button("Cancelar", action: onDismiss),
                trailing: Button(isSaving ? "Guardando..." : "Confirmar", action: onConfirm)
                    .disabled(isSaving)
            )
        }
    }
}
