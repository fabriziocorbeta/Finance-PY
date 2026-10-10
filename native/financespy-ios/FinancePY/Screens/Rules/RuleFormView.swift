import SwiftUI

struct RuleFormView: View {
    let rule: RuleDto?
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    private let api = FinancePyApi.shared

    @State private var name: String = ""
    @State private var resourceType: String = "transaction"
    @State private var active: Bool = true

    // Using a simple intermediate representation for form state
    struct FormCondition: Identifiable {
        let id = UUID()
        var conditionType: String = ""
        var operatorStr: String = ""
        var value: String = ""
        var originalId: String? = nil
        var destroy: Bool = false
    }

    struct FormAction: Identifiable {
        let id = UUID()
        var actionType: String = ""
        var value: String = ""
        var originalId: String? = nil
        var destroy: Bool = false
    }

    @State private var conditions: [FormCondition] = []
    @State private var actions: [FormAction] = []

    @State private var registry: RuleRegistryDto? = nil

    @State private var isSaving = false
    @State private var isLoadingRegistry = true
    @State private var errorMessage: String? = nil

    init(rule: RuleDto? = nil, onSaved: @escaping () -> Void) {
        self.rule = rule
        self.onSaved = onSaved
    }

    var body: some View {
        Form {
            if isLoadingRegistry {
                ProgressView("Cargando opciones...")
            } else if let errorMessage = errorMessage, registry == nil {
                Text("Error: \(errorMessage)").foregroundColor(.red)
            } else {
                Section(header: Text("Información Básica")) {
                    TextField("Nombre de la regla", text: $name)
                    Toggle("Activa", isOn: $active)
                }

                Section(header: Text("Condiciones")) {
                    ForEach($conditions) { $condition in
                        if !condition.destroy {
                            ConditionEditorView(condition: $condition, registry: registry)
                        }
                    }
                    .onDelete { indices in
                        for index in indices {
                            if conditions[index].originalId != nil {
                                conditions[index].destroy = true
                            } else {
                                conditions.remove(at: index)
                            }
                        }
                    }

                    Button("Agregar Condición") {
                        if let firstFilter = registry?.filters.first {
                            conditions.append(FormCondition(conditionType: firstFilter.key, operatorStr: firstFilter.operators?.first?.last ?? ""))
                        } else {
                            conditions.append(FormCondition())
                        }
                    }
                }

                Section(header: Text("Acciones")) {
                    ForEach($actions) { $action in
                        if !action.destroy {
                            ActionEditorView(action: $action, registry: registry)
                        }
                    }
                    .onDelete { indices in
                        for index in indices {
                            if actions[index].originalId != nil {
                                actions[index].destroy = true
                            } else {
                                actions.remove(at: index)
                            }
                        }
                    }

                    Button("Agregar Acción") {
                        if let firstExecutor = registry?.executors.first {
                            actions.append(FormAction(actionType: firstExecutor.key))
                        } else {
                            actions.append(FormAction())
                        }
                    }
                }

                Section {
                    Button(action: saveRule) {
                        if isSaving {
                            ProgressView().progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Guardar Regla")
                                .frame(maxWidth: .infinity)
                                .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                        }
                    }
                    .disabled(isSaving || name.isEmpty || conditions.filter { !$0.destroy }.isEmpty || actions.filter { !$0.destroy }.isEmpty)
                }
            }
        }
        .navigationTitle(rule == nil ? "Nueva Regla" : "Editar Regla")
        .onAppear {
            Task {
                await loadRegistryAndSetup()
            }
        }
    }

    private func loadRegistryAndSetup() async {
        do {
            registry = try await api.getRuleRegistry()

            if let rule = rule {
                name = rule.name ?? ""
                resourceType = rule.resourceType
                active = rule.active

                conditions = rule.conditions.map { c in
                    FormCondition(conditionType: c.conditionType, operatorStr: c.operatorStr, value: c.value ?? "", originalId: c.id)
                }

                actions = rule.actions.map { a in
                    FormAction(actionType: a.actionType, value: a.value ?? "", originalId: a.id)
                }
            }
        } catch {
            errorMessage = "Error al cargar opciones: \(error.localizedDescription)"
        }
        isLoadingRegistry = false
    }

    private func saveRule() {
        isSaving = true
        errorMessage = nil

        let conditionsAttrs = conditions.map { c in
            ConditionAttributes(
                conditionType: c.conditionType,
                operatorStr: c.operatorStr,
                value: c.value.isEmpty ? nil : c.value,
                subConditionsAttributes: nil,
                id: c.originalId,
                destroy: c.destroy ? true : nil
            )
        }

        let actionsAttrs = actions.map { a in
            ActionAttributes(
                actionType: a.actionType,
                value: a.value,
                id: a.originalId,
                destroy: a.destroy ? true : nil
            )
        }

        Task {
            do {
                if let rule = rule {
                    let request = UpdateRuleRequest(rule: UpdateRuleBody(
                        name: name,
                        active: active,
                        effectiveDate: nil,
                        conditionsAttributes: conditionsAttrs,
                        actionsAttributes: actionsAttrs
                    ))
                    _ = try await api.updateRule(id: rule.id, request: request)
                } else {
                    let request = CreateRuleRequest(rule: CreateRuleBody(
                        name: name,
                        resourceType: resourceType,
                        active: active,
                        effectiveDate: nil,
                        conditionsAttributes: conditionsAttrs,
                        actionsAttributes: actionsAttrs
                    ))
                    _ = try await api.createRule(request: request)
                }
                onSaved()
                dismiss()
            } catch {
                errorMessage = "Error al guardar: \(error.localizedDescription)"
                isSaving = false
            }
        }
    }
}

struct ConditionEditorView: View {
    @Binding var condition: RuleFormView.FormCondition
    let registry: RuleRegistryDto?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Tipo", selection: $condition.conditionType) {
                ForEach(registry?.filters ?? []) { filter in
                    Text(filter.label).tag(filter.key)
                }
            }
            .pickerStyle(MenuPickerStyle())

            if let selectedFilter = registry?.filters.first(where: { $0.key == condition.conditionType }) {
                Picker("Operador", selection: $condition.operatorStr) {
                    ForEach(selectedFilter.operators ?? [], id: \.self) { op in
                        if op.count >= 2 {
                            Text(op[0]).tag(op[1])
                        }
                    }
                }
                .pickerStyle(SegmentedPickerStyle())

                if let options = selectedFilter.options {
                    Picker("Valor", selection: $condition.value) {
                        ForEach(options, id: \.self) { opt in
                            if opt.count >= 2 {
                                Text(opt[0]).tag(opt[1])
                            }
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                } else {
                    TextField("Valor", text: $condition.value)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct ActionEditorView: View {
    @Binding var action: RuleFormView.FormAction
    let registry: RuleRegistryDto?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Acción", selection: $action.actionType) {
                ForEach(registry?.executors ?? []) { executor in
                    Text(executor.label).tag(executor.key)
                }
            }
            .pickerStyle(MenuPickerStyle())

            if let selectedExecutor = registry?.executors.first(where: { $0.key == action.actionType }) {
                if let options = selectedExecutor.options {
                    Picker("Valor", selection: $action.value) {
                        ForEach(options, id: \.self) { opt in
                            if opt.count >= 2 {
                                Text(opt[0]).tag(opt[1])
                            }
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                } else {
                    TextField("Valor", text: $action.value)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
            }
        }
        .padding(.vertical, 4)
    }
}
