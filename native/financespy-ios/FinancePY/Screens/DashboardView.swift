import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var syncEngine: SyncEngine

    @Query(sort: \AccountEntity.name)
    private var accounts: [AccountEntity]

    @Query(sort: \EntryEntity.date, order: .reverse)
    private var entries: [EntryEntity]

    private var recentEntries: [EntryEntity] {
        Array(entries.prefix(20))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Net Worth Card
                    VStack(spacing: 8) {
                        Text("Patrimonio Neto")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if let bs = syncEngine.balanceSheet {
                            Text(formatMoney(bs.netWorth))
                                .font(.system(size: 32, weight: .bold))

                            HStack(spacing: 24) {
                                VStack {
                                    Text("Activos")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text(formatMoney(bs.assets))
                                        .font(.footnote)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.green)
                                }

                                VStack {
                                    Text("Pasivos")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text(formatMoney(bs.liabilities))
                                        .font(.footnote)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.red)
                                }
                            }
                            .padding(.top, 4)
                        } else {
                            Text("--")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    if let syncError = syncEngine.lastSyncError {
                        Text(syncError)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }

                    // Accounts Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Cuentas (\(accounts.count))")
                            .font(.headline)
                            .padding(.horizontal)

                        if accounts.isEmpty {
                            Text("No hay cuentas guardadas.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(accounts) { account in
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(account.name)
                                                .font(.body)
                                                .fontWeight(.medium)
                                            Text(account.accountType.capitalized)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }

                                        Spacer()

                                        Text(formatCents(account.balanceCents, currency: account.currency))
                                            .font(.body)
                                            .fontWeight(.semibold)
                                    }
                                    .padding(.vertical, 12)
                                    .padding(.horizontal)

                                    Divider()
                                }
                            }
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                    }

                    // Recent Transactions Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Transacciones Recientes")
                            .font(.headline)
                            .padding(.horizontal)

                        if recentEntries.isEmpty {
                            Text("No hay transacciones recientes.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(recentEntries) { entry in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(entry.name)
                                                .font(.body)
                                                .fontWeight(.medium)

                                            HStack(spacing: 6) {
                                                if let cat = entry.transaction?.categoryName {
                                                    Text(cat)
                                                        .font(.caption2)
                                                        .padding(.horizontal, 6)
                                                        .padding(.vertical, 2)
                                                        .background(Color.accentColor.opacity(0.15))
                                                        .cornerRadius(4)
                                                }

                                                Text(entry.date)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }

                                        Spacer()

                                        let signedCents = entry.transaction?.signedAmountCents ?? entry.amountCents
                                        Text(formatCents(signedCents, currency: entry.currency))
                                            .font(.body)
                                            .fontWeight(.semibold)
                                            .foregroundColor(signedCents < 0 ? .red : .primary)
                                    }
                                    .padding(.vertical, 10)
                                    .padding(.horizontal)

                                    Divider()
                                }
                            }
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Inicio")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if syncEngine.isSyncing {
                        ProgressView()
                    } else {
                        Button("Actualizar") {
                            Task {
                                _ = await syncEngine.syncAll()
                            }
                        }
                    }
                }
            }
            .task {
                if accounts.isEmpty {
                    _ = await syncEngine.syncAll()
                }
            }
        }
    }

    private func formatMoney(_ money: MoneyDto) -> String {
        if let amount = money.amount, let currency = money.currency {
            return "\(currency) \(amount)"
        } else if let cents = money.cents {
            return formatCents(cents, currency: money.currency ?? "PYG")
        } else {
            return "--"
        }
    }

    private func formatCents(_ cents: Int64, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        let amount = Double(cents) / 100.0
        return formatter.string(from: NSNumber(value: amount)) ?? "\(currency) \(amount)"
    }
}
