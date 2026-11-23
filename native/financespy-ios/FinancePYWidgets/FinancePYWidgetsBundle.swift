import SwiftUI
import WidgetKit

// MARK: - Shared Timeline Entry

struct FinanceWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

struct FinanceWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> FinanceWidgetEntry {
        FinanceWidgetEntry(date: Date(), snapshot: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (FinanceWidgetEntry) -> Void) {
        completion(FinanceWidgetEntry(date: Date(), snapshot: WidgetDataStore.shared.loadSnapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FinanceWidgetEntry>) -> Void) {
        let entry = FinanceWidgetEntry(date: Date(), snapshot: WidgetDataStore.shared.loadSnapshot())
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

private func formatWidgetAmount(_ cents: Int64, currency: String) -> String {
    let upper = currency.uppercased()
    let value = upper == "PYG" ? Double(cents) : Double(cents) / 100.0
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.groupingSeparator = "."
    formatter.decimalSeparator = ","
    formatter.maximumFractionDigits = upper == "PYG" ? 0 : 2
    formatter.minimumFractionDigits = upper == "PYG" ? 0 : 2
    let formatted = formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    return upper == "PYG" ? "Gs. \(formatted)" : "\(upper) \(formatted)"
}

// MARK: - Balance Widget (Líquido disponible)

struct BalanceWidgetView: View {
    let entry: FinanceWidgetEntry
    @Environment(\.widgetFamily) private var family

    private let greenColor = Color(red: 22/255, green: 163/255, blue: 74/255)
    private let redColor = Color(red: 225/255, green: 29/255, blue: 72/255)

    var body: some View {
        if let snapshot = entry.snapshot {
            let total = max(Double(abs(snapshot.assetsCents) + abs(snapshot.liabilitiesCents)), 1.0)
            let liquidRatio = min(max(Double(max(snapshot.liquidAvailableCents, 0)) / total, 0.0), 1.0)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Líquido disponible")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                    Image(systemName: "banknote")
                        .font(.caption)
                        .foregroundColor(greenColor)
                }

                Text(formatWidgetAmount(snapshot.liquidAvailableCents, currency: snapshot.currency))
                    .font(family == .systemSmall ? .headline.weight(.bold) : .title2.weight(.bold))
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.gray.opacity(0.18))
                        Capsule()
                            .fill(greenColor)
                            .frame(width: geo.size.width * liquidRatio)
                    }
                }
                .frame(height: 6)

                if family != .systemSmall {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Activos")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(formatWidgetAmount(snapshot.assetsCents, currency: snapshot.currency))
                                .font(.caption.weight(.semibold))
                                .foregroundColor(greenColor)
                                .lineLimit(1)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Pasivos")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(formatWidgetAmount(snapshot.liabilitiesCents, currency: snapshot.currency))
                                .font(.caption.weight(.semibold))
                                .foregroundColor(redColor)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .padding()
            .containerBackground(.background, for: .widget)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("Líquido disponible")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                Text("Abrí FinancePY para sincronizar")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .containerBackground(.background, for: .widget)
        }
    }
}

struct BalanceWidget: Widget {
    let kind: String = "FinancePYBalanceWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FinanceWidgetProvider()) { entry in
            BalanceWidgetView(entry: entry)
        }
        .configurationDisplayName("Líquido disponible")
        .description("Muestra tu saldo líquido real en cuentas de efectivo y banco.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Expenses Widget (Gastos recientes)

struct ExpensesWidgetView: View {
    let entry: FinanceWidgetEntry
    @Environment(\.widgetFamily) private var family

    private let redColor = Color(red: 225/255, green: 29/255, blue: 72/255)

    var body: some View {
        if let snapshot = entry.snapshot {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Gastos del mes")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                    Image(systemName: "arrow.down.right.circle.fill")
                        .font(.caption)
                        .foregroundColor(redColor)
                }

                Text(formatWidgetAmount(snapshot.monthlyExpensesCents, currency: snapshot.currency))
                    .font(family == .systemSmall ? .headline.weight(.bold) : .title3.weight(.bold))
                    .foregroundColor(redColor)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)

                if family != .systemSmall {
                    Divider()
                    ForEach(snapshot.recentExpenses.prefix(3)) { item in
                        HStack {
                            Text(item.name)
                                .font(.caption2)
                                .lineLimit(1)
                            Spacer()
                            Text(formatWidgetAmount(abs(item.amountCents), currency: item.currency))
                                .font(.caption2.weight(.semibold))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                        }
                    }
                } else if let latest = snapshot.recentExpenses.first {
                    Text("Último: \(latest.name)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .padding()
            .containerBackground(.background, for: .widget)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("Gastos del mes")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                Text("Abrí FinancePY para sincronizar")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .containerBackground(.background, for: .widget)
        }
    }
}

struct ExpensesWidget: Widget {
    let kind: String = "FinancePYExpensesWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FinanceWidgetProvider()) { entry in
            ExpensesWidgetView(entry: entry)
        }
        .configurationDisplayName("Gastos recientes")
        .description("Muestra tus gastos del mes y los últimos movimientos.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Widget Bundle

@main
struct FinancePYWidgetsBundle: WidgetBundle {
    var body: some Widget {
        BalanceWidget()
        ExpensesWidget()
    }
}
