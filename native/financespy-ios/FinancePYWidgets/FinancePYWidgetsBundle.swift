import SwiftUI
import WidgetKit

// MARK: - Finance-PY Matte Dark Mode Fintech Palette

private enum WidgetTheme {
    static let obsidianBg = Color(red: 14 / 255, green: 17 / 255, blue: 22 / 255)      // #0E1116
    static let cardSurface = Color(red: 24 / 255, green: 29 / 255, blue: 38 / 255)     // #181D26
    static let elevatedSurface = Color(red: 31 / 255, green: 38 / 255, blue: 51 / 255) // #1F2633
    static let borderSubtle = Color(red: 38 / 255, green: 46 / 255, blue: 61 / 255)    // #262E3D
    static let emeraldPrimary = Color(red: 16 / 255, green: 185 / 255, blue: 129 / 255)// #10B981
    static let coralDanger = Color(red: 239 / 255, green: 68 / 255, blue: 68 / 255)    // #EF4444
    static let amberWarning = Color(red: 245 / 255, green: 158 / 255, blue: 11 / 255)  // #F59E0B
    static let textPrimary = Color(red: 249 / 255, green: 250 / 255, blue: 251 / 255)  // #F9FAFB
    static let textMuted = Color(red: 156 / 255, green: 163 / 255, blue: 175 / 255)    // #9CA3AF
}

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

// MARK: - Balance Widget (Disponible / Líquido)

struct BalanceWidgetView: View {
    let entry: FinanceWidgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if let snapshot = entry.snapshot {
                let total = max(Double(abs(snapshot.assetsCents) + abs(snapshot.liabilitiesCents)), 1.0)
                let liquidRatio = min(max(Double(max(snapshot.liquidAvailableCents, 0)) / total, 0.0), 1.0)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("DISPONIBLE")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(0.8)
                            .foregroundColor(WidgetTheme.textMuted)
                        Spacer()
                        Image(systemName: "arrow.up.right.circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(WidgetTheme.emeraldPrimary)
                    }

                    Text(formatWidgetAmount(snapshot.liquidAvailableCents, currency: snapshot.currency))
                        .font(.system(size: family == .systemSmall ? 20 : 24, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(WidgetTheme.textPrimary)
                        .minimumScaleFactor(0.72)
                        .lineLimit(1)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(WidgetTheme.elevatedSurface)
                            Capsule()
                                .fill(WidgetTheme.emeraldPrimary)
                                .frame(width: geo.size.width * liquidRatio)
                        }
                    }
                    .frame(height: 6)

                    if family != .systemSmall {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Activos")
                                    .font(.caption2)
                                    .foregroundColor(WidgetTheme.textMuted)
                                Text(formatWidgetAmount(snapshot.assetsCents, currency: snapshot.currency))
                                    .font(.caption.weight(.semibold))
                                    .monospacedDigit()
                                    .foregroundColor(WidgetTheme.emeraldPrimary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("Pasivos")
                                    .font(.caption2)
                                    .foregroundColor(WidgetTheme.textMuted)
                                Text(formatWidgetAmount(snapshot.liabilitiesCents, currency: snapshot.currency))
                                    .font(.caption.weight(.semibold))
                                    .monospacedDigit()
                                    .foregroundColor(WidgetTheme.coralDanger)
                                    .lineLimit(1)
                            }
                        }
                    } else {
                        Text("\(Int(liquidRatio * 100))% liquidez s/ balance")
                            .font(.system(size: 10, weight: .medium))
                            .monospacedDigit()
                            .foregroundColor(WidgetTheme.textMuted)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("DISPONIBLE")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.8)
                        .foregroundColor(WidgetTheme.textMuted)
                    Text("Abrí FinancePY para sincronizar")
                        .font(.caption)
                        .foregroundColor(WidgetTheme.textMuted)
                }
            }
        }
        .padding(14)
        .widgetURL(URL(string: "financespy://widgets/available"))
        .containerBackground(for: .widget) {
            WidgetTheme.obsidianBg
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

// MARK: - Expenses Widget (Gastos del ciclo y últimos movimientos)

struct ExpensesWidgetView: View {
    let entry: FinanceWidgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if let snapshot = entry.snapshot {
                if family == .systemMedium {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("GASTOS MES")
                                    .font(.system(size: 10, weight: .semibold))
                                    .tracking(0.8)
                                    .foregroundColor(WidgetTheme.textMuted)
                                Spacer()
                                Image(systemName: "arrow.down.right.circle.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(WidgetTheme.coralDanger)
                            }
                            Spacer()
                            Text(formatWidgetAmount(snapshot.monthlyExpensesCents, currency: snapshot.currency))
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundColor(WidgetTheme.coralDanger)
                                .minimumScaleFactor(0.72)
                                .lineLimit(1)
                            Text("\(snapshot.recentExpenses.count) movimientos recientes")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(WidgetTheme.textMuted)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("MOVIMIENTOS")
                                .font(.system(size: 9, weight: .semibold))
                                .tracking(0.8)
                                .foregroundColor(WidgetTheme.textMuted)

                            ForEach(snapshot.recentExpenses.prefix(3)) { item in
                                HStack(spacing: 6) {
                                    Text(item.name)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(WidgetTheme.textPrimary)
                                        .lineLimit(1)
                                    Spacer()
                                    Text("-\(formatWidgetAmount(abs(item.amountCents), currency: item.currency))")
                                        .font(.system(size: 11, weight: .semibold))
                                        .monospacedDigit()
                                        .foregroundColor(WidgetTheme.textMuted)
                                        .lineLimit(1)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity)
                        .background(WidgetTheme.cardSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("GASTOS MES")
                                .font(.system(size: 10, weight: .semibold))
                                .tracking(0.8)
                                .foregroundColor(WidgetTheme.textMuted)
                            Spacer()
                            Image(systemName: "arrow.down.right.circle.fill")
                                .font(.system(size: 13))
                                .foregroundColor(WidgetTheme.coralDanger)
                        }
                        Spacer()
                        Text(formatWidgetAmount(snapshot.monthlyExpensesCents, currency: snapshot.currency))
                            .font(.system(size: 19, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(WidgetTheme.coralDanger)
                            .minimumScaleFactor(0.72)
                            .lineLimit(1)
                        if let latest = snapshot.recentExpenses.first {
                            Text("Último: \(latest.name)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(WidgetTheme.textMuted)
                                .lineLimit(1)
                        }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("GASTOS MES")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.8)
                        .foregroundColor(WidgetTheme.textMuted)
                    Text("Abrí FinancePY para sincronizar")
                        .font(.caption)
                        .foregroundColor(WidgetTheme.textMuted)
                }
            }
        }
        .padding(14)
        .widgetURL(URL(string: "financespy://widgets/recent_expenses"))
        .containerBackground(for: .widget) {
            WidgetTheme.obsidianBg
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
