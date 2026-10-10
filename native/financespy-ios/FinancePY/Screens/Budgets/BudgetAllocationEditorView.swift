import SwiftUI

struct BudgetAllocationEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let budget: BudgetDto
    let onSaved: () -> Void

    @State private var allocations: [String: String] = [:]
    @State private var isSaving = false
    @State private var error: String? = nil

    // Computed state
    private var totalAllocated: Double {
        allocations.values.compactMap { Double($0) }.reduce(0, +)
    }

    private var availableToAllocate: Double {
        (budget.expectedIncome ?? 0) - totalAllocated
    }

    private var allocatedPercent: Double {
        let expected = budget.expectedIncome ?? 0
        if expected == 0 { return 0 }
        return (totalAllocated / expected) * 100
    }

    var body: some View {
        VStack(spacing: 0) {
            // Summary Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Asignación total")
                    .font(.headline)

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color(.systemGray5))

                        let width = geometry.size.width * CGFloat(min(allocatedPercent / 100.0, 1.0))
                        Rectangle()
                            .fill(availableToAllocate < 0 ? Color.red : Color.blue)
                            .frame(width: width)
                    }
                }
                .frame(height: 8)
                .cornerRadius(4)

                HStack {
                    Text(availableToAllocate < 0 ?
                         "Superaste el presupuesto por \(formatMoney(-availableToAllocate))" :
                         "\(Int(allocatedPercent))% asignado (\(formatMoney(totalAllocated)) / \(formatMoney(budget.expectedIncome ?? 0)))"
                    )
                    .font(.caption)
                    .foregroundColor(availableToAllocate < 0 ? .red : .secondary)

                    Spacer()

                    Text("Disponible: \(formatMoney(availableToAllocate))")
                        .font(.caption)
                        .bold()
                        .foregroundColor(availableToAllocate < 0 ? .red : .primary)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))

            if let error = error {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            }

            // Categories List
            List {
                ForEach(budget.categories ?? []) { category in
                    HStack {
                        if category.subcategory {
                            Image(systemName: "arrow.turn.down.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                                .padding(.leading, 16)
                        }

                        Circle().fill(Color(hex: category.categoryColor ?? "#CCCCCC") ?? .gray)
                            .frame(width: 12, height: 12)

                        VStack(alignment: .leading) {
                            Text(category.categoryName ?? "")
                                .font(.body)
                            if category.subcategory && category.inheritsParentBudget {
                                Text("Compartido con la categoría principal")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        TextField(budget.currency ?? "USD", text: binding(for: category.id))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.plain)

            // Save Button
            Button(action: saveAllocations) {
                if isSaving {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Confirmar")
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(availableToAllocate < 0 || isSaving ? Color.gray : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
            .padding()
            .disabled(availableToAllocate < 0 || isSaving)
        }
        .navigationTitle("Asignaciones")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            initializeAllocations()
        }
    }

    private func initializeAllocations() {
        for category in budget.categories ?? [] {
            if let spending = category.budgetedSpending {
                allocations[category.id] = String(spending)
            }
        }
    }

    private func binding(for id: String) -> Binding<String> {
        Binding(
            get: { self.allocations[id] ?? "" },
            set: { self.allocations[id] = $0 }
        )
    }

    private func formatMoney(_ amount: Double) -> String {
        return "\(budget.currency ?? "USD") \(amount)"
    }

    private func saveAllocations() {
        isSaving = true
        error = nil

        Task {
            do {
                for (categoryId, amountStr) in allocations {
                    if let category = budget.categories?.first(where: { $0.id == categoryId }) {
                        let newAmount = Double(amountStr) ?? 0
                        if newAmount != (category.budgetedSpending ?? 0) {
                            _ = try await FinancePyApi.shared.updateBudgetCategory(
                                budgetId: budget.id,
                                categoryId: category.id,
                                budgetedSpending: newAmount
                            )
                        }
                    }
                }
                onSaved()
                dismiss()
            } catch {
                self.error = "Error al guardar: \(error.localizedDescription)"
                isSaving = false
            }
        }
    }
}
