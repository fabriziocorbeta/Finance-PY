import SwiftUI
import SwiftData

struct TransactionsView: View {
    @Query(sort: \AccountEntity.name)
    private var accounts: [AccountEntity]

    @Query(sort: \EntryEntity.date, order: .reverse)
    private var entries: [EntryEntity]

    @State private var selectedAccountId: String = "ALL"

    private var filteredEntries: [EntryEntity] {
        if selectedAccountId == "ALL" {
            return entries
        } else {
            return entries.filter { $0.accountId == selectedAccountId }
        }
    }

    var body: some View {
        NavigationStack {
            VStack {
                // Filter Picker
                Picker("Cuenta", selection: $selectedAccountId) {
                    Text("Todas las cuentas").tag("ALL")
                    ForEach(accounts) { account in
                        Text(account.name).tag(account.id)
                    }
                }
                .pickerStyle(.menu)
                .padding(.horizontal)
                .padding(.top, 8)

                if filteredEntries.isEmpty {
                    Spacer()
                    Text("No hay transacciones guardadas.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                } else {
                    List(filteredEntries) { entry in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.name)
                                    .font(.body)
                                    .fontWeight(.medium)

                                HStack(spacing: 8) {
                                    if let accountName = accountName(for: entry.accountId) {
                                        Text(accountName)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }

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
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Transacciones")
        }
    }

    private func accountName(for accountId: String) -> String? {
        accounts.first(where: { $0.id == accountId })?.name
    }

    private func formatCents(_ cents: Int64, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        let amount = Double(cents) / 100.0
        return formatter.string(from: NSNumber(value: amount)) ?? "\(currency) \(amount)"
    }
}
