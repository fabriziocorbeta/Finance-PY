import SwiftUI

struct RuleDetailView: View {
    let rule: RuleDto
    let onDeleted: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isDeleting = false
    @State private var errorMessage: String? = nil

    private let api = FinancePyApi.shared

    var body: some View {
        List {
            Section(header: Text("Información Básica")) {
                LabeledContent("Nombre", value: rule.name ?? "-")
                LabeledContent("Recurso", value: rule.resourceType)
                LabeledContent("Estado", value: rule.active ? "Activa" : "Inactiva")
                if let effectiveDate = rule.effectiveDate {
                    LabeledContent("Fecha Efectiva", value: effectiveDate)
                }
            }

            Section(header: Text("Condiciones")) {
                if rule.conditions.isEmpty {
                    Text("Sin condiciones")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(rule.conditions) { condition in
                        ConditionRowView(condition: condition)
                    }
                }
            }

            Section(header: Text("Acciones")) {
                if rule.actions.isEmpty {
                    Text("Sin acciones")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(rule.actions) { action in
                        VStack(alignment: .leading) {
                            Text(action.actionType).font(.subheadline).bold()
                            if let value = action.value {
                                Text("Valor: \(value)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }

            if let errorMessage = errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }
            }

            Section {
                Button(role: .destructive, action: deleteRule) {
                    HStack {
                        Spacer()
                        if isDeleting {
                            ProgressView()
                        } else {
                            Text("Eliminar Regla")
                        }
                        Spacer()
                    }
                }
                .disabled(isDeleting)
            }
        }
        .navigationTitle("Detalle de Regla")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: RuleFormView(rule: rule, onSaved: {
                    onDeleted() // Refresh list, then pop
                    dismiss()
                })) {
                    Text("Editar")
                }
            }
        }
    }

    private func deleteRule() {
        isDeleting = true
        errorMessage = nil
        Task {
            do {
                try await api.deleteRule(id: rule.id)
                onDeleted()
                dismiss()
            } catch {
                errorMessage = "Error al eliminar: \(error.localizedDescription)"
                isDeleting = false
            }
        }
    }
}

struct ConditionRowView: View {
    let condition: RuleConditionDto

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(condition.conditionType).font(.subheadline).bold()
            HStack {
                Text(condition.operatorStr)
                    .font(.caption)
                    .foregroundColor(.blue)
                if let value = condition.value {
                    Text(value)
                        .font(.caption)
                }
            }
            if let subs = condition.subConditions, !subs.isEmpty {
                ForEach(subs) { sub in
                    HStack {
                        Rectangle().frame(width: 2).foregroundColor(.gray).padding(.leading, 8)
                        ConditionRowView(condition: sub)
                    }
                }
            }
        }
    }
}
