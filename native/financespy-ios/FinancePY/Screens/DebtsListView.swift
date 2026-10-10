import SwiftUI
import SwiftData

struct DebtsListView: View {
    @Query(
        filter: #Predicate<AccountEntity> { $0.classification == "liability" },
        sort: \AccountEntity.name
    )
    private var debts: [AccountEntity]

    private var totalOwedByCurrency: [String: Int64] {
        Dictionary(grouping: debts, by: { $0.currency })
            .mapValues { accounts in
                accounts.reduce(0) { $0 + $1.balanceCents }
            }
    }

    var body: some View {
        NavigationStack {
            List {
                if totalOwedByCurrency.isEmpty {
                    Text("No hay deudas registradas.")
                        .foregroundColor(.secondary)
                } else {
                    Section(header: Text("Resumen de Deudas")) {
                        ForEach(totalOwedByCurrency.keys.sorted(), id: \.self) { currency in
                            if let total = totalOwedByCurrency[currency] {
                                HStack {
                                    Text(currency)
                                        .fontWeight(.bold)
                                    Spacer()
                                    Text(formatCents(total, currency: currency))
                                        .foregroundColor(.red)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                    }

                    Section(header: Text("Cuentas por pagar")) {
                        ForEach(debts) { debt in
                            NavigationLink(destination: AccountDetailView(accountId: debt.id)) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(debt.name)
                                            .font(.body)
                                            .fontWeight(.medium)
                                        Text(debt.accountType.capitalized)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Text(formatCents(debt.balanceCents, currency: debt.currency))
                                        .foregroundColor(.red)
                                        .fontWeight(.medium)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Deudas")
            .listStyle(.insetGrouped)
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
