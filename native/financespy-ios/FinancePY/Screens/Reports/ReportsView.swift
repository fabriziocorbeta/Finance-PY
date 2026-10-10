import SwiftUI

struct ReportsView: View {
    @StateObject private var viewModel = ReportsViewModel()

    var body: some View {
        NavigationStack {
            VStack {
                // Header / Picker
                Picker("Período", selection: $viewModel.periodType) {
                    Text("Mensual").tag("monthly")
                    Text("Personalizado").tag("custom")
                }
                .pickerStyle(.segmented)
                .padding()

                if viewModel.periodType == "custom" {
                    HStack {
                        DatePicker("", selection: $viewModel.startDate, displayedComponents: .date)
                            .labelsHidden()
                        Text(" - ")
                        DatePicker("", selection: $viewModel.endDate, displayedComponents: .date)
                            .labelsHidden()

                        Button("Buscar") {
                            Task {
                                await viewModel.fetchReports()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.leading, 8)
                    }
                    .padding(.horizontal)
                }

                if viewModel.isLoading {
                    Spacer()
                    ProgressView("Cargando reportes...")
                    Spacer()
                } else if let error = viewModel.errorMessage {
                    Spacer()
                    Text(error)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                    Button("Reintentar") {
                        Task { await viewModel.fetchReports() }
                    }
                    Spacer()
                } else if let summary = viewModel.summary {
                    ScrollView {
                        VStack(spacing: 20) {

                            // Net Worth
                            NetWorthCard(netWorth: summary.netWorth, currency: summary.currency)

                            // Summary Metrics
                            SummaryMetricsCard(metrics: summary.summary, currency: summary.currency)

                            // Category Breakdowns
                            CategoryBreakdownCard(
                                title: "Ingresos por Categoría",
                                breakdown: summary.transactionsBreakdown.income,
                                currency: summary.currency,
                                color: .green
                            )

                            CategoryBreakdownCard(
                                title: "Gastos por Categoría",
                                breakdown: summary.transactionsBreakdown.expense,
                                currency: summary.currency,
                                color: .red
                            )

                            // TODO: Sankey chart / Cash Flow visualization
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Flujo de Efectivo")
                                    .font(.headline)
                                Text("// TODO: Sankey chart")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, minHeight: 150)
                                    .background(Color(.secondarySystemBackground))
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal)

                            if let invMetrics = summary.investmentMetrics, invMetrics.hasInvestments {
                                InvestmentMetricsCard(metrics: invMetrics, currency: summary.currency)
                            }

                            if let invFlows = summary.investmentFlows {
                                InvestmentFlowsCard(flows: invFlows, currency: summary.currency)
                            }
                        }
                        .padding(.vertical)
                    }
                } else {
                    Spacer()
                    Text("No hay datos")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
            .navigationTitle("Reportes")
            .task {
                if viewModel.summary == nil {
                    await viewModel.fetchReports()
                }
            }
        }
    }
}

// MARK: - Subviews

struct NetWorthCard: View {
    let netWorth: ReportNetWorthDto
    let currency: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Patrimonio Neto")
                .font(.headline)

            HStack {
                Text(formatMoney(netWorth.current, currency: currency))
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                if let pct = netWorth.changePct {
                    let isPositive = pct >= 0
                    Text(String(format: "%@%.1f%%", isPositive ? "+" : "", pct))
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(isPositive ? .green : .red)
                }
            }

            HStack {
                VStack(alignment: .leading) {
                    Text("Activos totales")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatMoney(netWorth.totalAssets, currency: currency))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Pasivos totales")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatMoney(netWorth.totalLiabilities, currency: currency))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct SummaryMetricsCard: View {
    let metrics: ReportSummaryMetricsDto
    let currency: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Resumen del Período")
                .font(.headline)

            HStack {
                VStack(alignment: .leading) {
                    Text("Ingresos")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatMoney(metrics.income, currency: currency))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
                Spacer()
                VStack(alignment: .leading) {
                    Text("Gastos")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatMoney(metrics.expense, currency: currency))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Ahorro Neto")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatMoney(metrics.netSavings, currency: currency))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(metrics.netSavings >= 0 ? .green : .red)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct CategoryBreakdownCard: View {
    let title: String
    let breakdown: [ReportCategoryBreakdownDto]
    let currency: String?
    let color: Color

    var body: some View {
        if !breakdown.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.headline)
                    .padding(.horizontal)

                VStack(spacing: 0) {
                    ForEach(breakdown) { item in
                        HStack {
                            Text(item.categoryName)
                                .font(.subheadline)
                            Spacer()
                            Text(formatMoney(item.total, currency: currency))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(color)
                        }
                        .padding(.vertical, 8)
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
}

struct InvestmentMetricsCard: View {
    let metrics: ReportInvestmentMetricsDto
    let currency: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Inversiones")
                .font(.headline)

            Text("Valor del Portafolio: \(formatMoney(metrics.portfolioValue, currency: currency))")
                .font(.subheadline)
                .fontWeight(.bold)

            if !metrics.topHoldings.isEmpty {
                Text("Principales Activos")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)

                ForEach(metrics.topHoldings) { holding in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(holding.ticker)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text(holding.name)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text(formatMoney(holding.amount, currency: currency))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text(String(format: "%.1f%% del portafolio", holding.weight * 100))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct InvestmentFlowsCard: View {
    let flows: ReportInvestmentFlowsDto
    let currency: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Flujos de Inversión")
                .font(.headline)

            HStack {
                VStack(alignment: .leading) {
                    Text("Contribuciones")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatMoney(flows.contributions, currency: currency))
                        .font(.subheadline)
                        .foregroundColor(.green)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Retiros")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatMoney(flows.withdrawals, currency: currency))
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
            }

            HStack {
                Spacer()
                Text("Flujo Neto: ")
                    .font(.subheadline)
                Text(formatMoney(flows.netFlow, currency: currency))
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(flows.netFlow >= 0 ? .green : .red)
            }
            .padding(.top, 4)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

// Helper to match API formats where backend mostly sends floats instead of ints for reports
private func formatMoney(_ amount: Double, currency: String?) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = currency ?? "PYG"
    return formatter.string(from: NSNumber(value: amount)) ?? "\(currency ?? "PYG") \(amount)"
}
