import SwiftUI
import SwiftData

struct ReceivablesListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ReceivableEntity.name) private var receivables: [ReceivableEntity]

    @State private var isLoading = false
    @State private var error: String? = nil

    var body: some View {
        NavigationStack {
            VStack {
                if let error = error {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                        .background(Color(.systemRed).opacity(0.1))
                        .cornerRadius(8)
                        .padding()
                }

                NavigationLink(destination: ReceivableFormView()) {
                    Text("Nueva cuenta a cobrar")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                        .padding(.horizontal)
                        .padding(.top)
                }

                if receivables.isEmpty && !isLoading {
                    Spacer()
                    Text("No hay cuentas a cobrar registradas.")
                        .foregroundColor(.secondary)
                    Spacer()
                } else {
                    List {
                        ForEach(receivables) { receivable in
                            NavigationLink(destination: ReceivableDetailView(receivableId: receivable.id)) {
                                ReceivableRow(receivable: receivable)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Cuentas a Cobrar")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isLoading {
                        ProgressView()
                    } else {
                        Button("Actualizar") {
                            Task { await refresh() }
                        }
                    }
                }
            }
            .task {
                if receivables.isEmpty {
                    await refresh()
                }
            }
        }
    }

    private func refresh() async {
        isLoading = true
        error = nil
        do {
            let remote = try await FinancePyApi.shared.fetchReceivables()

            // Upsert remote receivables
            let remoteIds = Set(remote.map { $0.id })

            let descriptor = FetchDescriptor<ReceivableEntity>()
            let localReceivables = try modelContext.fetch(descriptor)
            let localDict = Dictionary(uniqueKeysWithValues: localReceivables.map { ($0.id, $0) })

            for dto in remote {
                let installmentScheduleData: Data? = {
                    if let schedule = dto.installmentSchedule {
                        let encoder = JSONEncoder()
                        encoder.keyEncodingStrategy = .convertToSnakeCase
                        return try? encoder.encode(schedule)
                    }
                    return nil
                }()

                if let existing = localDict[dto.id] {
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
            }

            // Delete receivables no longer present remotely
            for local in localReceivables {
                if !remoteIds.contains(local.id) {
                    modelContext.delete(local)
                }
            }

            try modelContext.save()

        } catch {
            self.error = "Error al cargar las cuentas a cobrar: \(error.localizedDescription)"
        }
        isLoading = false
    }
}

struct ReceivableRow: View {
    let receivable: ReceivableEntity

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(receivable.name)
                    .font(.headline)
                Spacer()
                Text(formatMoney(amount: receivable.totalAmount, currency: receivable.currency))
                    .font(.headline)
            }

            HStack {
                Text("Saldo: \(formatMoney(amount: receivable.balance, currency: receivable.currency))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text("Cobrado: \(Int(receivable.percentPaid))%")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            }

            let progress = max(0.0, min(1.0, receivable.percentPaid / 100.0))
            ProgressView(value: progress)
                .tint(.green)

            if receivable.installmentCount != nil || receivable.dueDay != nil {
                let cuotasText = receivable.installmentCount.map { "\($0) cuotas" }
                let dueDayText = receivable.dueDay.map { "Día \($0)" }
                let extraInfo = [cuotasText, dueDayText].compactMap { $0 }.joined(separator: " • ")

                if !extraInfo.isEmpty {
                    HStack {
                        Text(extraInfo)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }

    private func formatMoney(amount: Double, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: amount)) ?? "\(currency) \(amount)"
    }
}
