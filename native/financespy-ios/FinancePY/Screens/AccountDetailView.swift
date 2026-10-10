import SwiftUI
import SwiftData

struct AccountDetailView: View {
    let accountId: String

    @Query private var allAccounts: [AccountEntity]
    @Query(sort: \EntryEntity.date, order: .reverse) private var allEntries: [EntryEntity]

    private var account: AccountEntity? {
        allAccounts.first { $0.id == accountId }
    }

    private var entries: [EntryEntity] {
        allEntries.filter { $0.accountId == accountId }
    }

    var body: some View {
        Group {
            if let account = account {
                List {
                    Section {
                        VStack(alignment: .center, spacing: 8) {
                            Text(account.name)
                                .font(.title2)
                                .fontWeight(.bold)

                            Text(formatCents(account.balanceCents, currency: account.currency))
                                .font(.largeTitle)
                                .fontWeight(.heavy)
                                .foregroundColor(account.balanceCents < 0 ? .red : .primary)

                            if account.accountType == "depository" && account.balanceCents != account.cashBalanceCents {
                                Text("Saldo disponible: \(formatCents(account.cashBalanceCents, currency: account.currency))")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }

                            HStack {
                                Text(account.accountType.capitalized)
                                if let subtype = account.subtype {
                                    Text("• \(subtype)")
                                }
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical)
                    }

                    Section(header: Text("Movimientos")) {
                        if entries.isEmpty {
                            Text("No hay movimientos recientes.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.vertical)
                        } else {
                            ForEach(entries) { entry in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(entry.name)
                                            .font(.body)
                                            .fontWeight(.medium)

                                        HStack(spacing: 8) {
                                            if let cat = entry.transaction?.categoryName {
                                                Text(cat)
                                                    .font(.caption2)
                                                    .foregroundColor(.accentColor)
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
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .navigationTitle("Detalle de cuenta")
                .navigationBarTitleDisplayMode(.inline)
            } else {
                Text("Cuenta no encontrada")
                    .foregroundColor(.secondary)
            }
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
