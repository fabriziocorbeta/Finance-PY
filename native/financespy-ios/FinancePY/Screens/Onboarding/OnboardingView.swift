import SwiftUI

struct GoalOption: Identifiable {
    let id: String
    let title: String
}

let GOAL_OPTIONS = [
    GoalOption(id: "unified_accounts", title: "Ver todas mis cuentas en un solo lugar"),
    GoalOption(id: "cashflow", title: "Entender el flujo de caja y los gastos"),
    GoalOption(id: "budgeting", title: "Gestionar planes financieros y presupuestos"),
    GoalOption(id: "partner", title: "Gestionar finanzas con mi pareja"),
    GoalOption(id: "investments", title: "Seguir las inversiones"),
    GoalOption(id: "ai_insights", title: "Dejar que la IA me ayude a entender mis finanzas"),
    GoalOption(id: "optimization", title: "Analizar y optimizar cuentas"),
    GoalOption(id: "reduce_stress", title: "Reducir el estrés financiero o la ansiedad")
]

struct OnboardingView: View {
    let onComplete: () -> Void

    @State private var step = 1
    @State private var isLoading = false
    @State private var errorMessage: String?

    // Step 1
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var moniker = "Family"
    @State private var familyName = ""
    @State private var country = "PY"

    // Step 2
    @State private var theme = "system"
    @State private var locale = "es"
    @State private var currency = "PYG"
    @State private var dateFormat = "%d/%m/%Y"

    // Step 3
    @State private var selectedGoals = Set<String>()

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    Spacer().frame(height: 16)

                    Text(titleForStep)
                        .font(.title)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    Text(subtitleForStep)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 8) {
                        ForEach(1...3, id: \.self) { i in
                            Rectangle()
                                .fill(i <= step ? Color.blue : Color.gray.opacity(0.3))
                                .frame(height: 8)
                                .cornerRadius(4)
                        }
                    }
                    .padding(.horizontal)

                    if let err = errorMessage {
                        Text(err)
                            .foregroundColor(.red)
                            .font(.caption)
                    }

                    VStack(spacing: 20) {
                        if step == 1 {
                            stepOne
                        } else if step == 2 {
                            stepTwo
                        } else if step == 3 {
                            stepThree
                        }
                    }
                    .padding(.horizontal)

                    Spacer().frame(height: 40)
                }
            }

            // Bottom Action Bar
            VStack {
                Divider()
                HStack {
                    if step > 1 {
                        Button("Atrás") {
                            withAnimation {
                                step -= 1
                            }
                        }
                        .disabled(isLoading)
                    } else {
                        Spacer().frame(width: 44) // Placeholder to keep center alignment
                    }

                    Spacer()

                    if isLoading {
                        ProgressView()
                    } else if step < 3 {
                        Button("Continuar") {
                            withAnimation {
                                step += 1
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button("Completar") {
                            completeOnboarding()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
            }
            .background(Color(UIColor.systemBackground))
        }
    }

    private var titleForStep: String {
        switch step {
        case 1: return "Configuremos tu cuenta"
        case 2: return "Configura tus preferencias"
        default: return "¿Qué te trae por aquí?"
        }
    }

    private var subtitleForStep: String {
        switch step {
        case 1: return "Primero, completemos tu perfil."
        case 2: return "Configuremos tus preferencias."
        default: return "Selecciona uno o más objetivos que tienes con la herramienta."
        }
    }

    private var stepOne: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("Nombre", text: $firstName)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            TextField("Apellido", text: $lastName)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            VStack(alignment: .leading, spacing: 12) {
                Text("Usaré la app con...")
                    .fontWeight(.bold)

                Picker("Usaré la app con...", selection: $moniker) {
                    Text("Miembros de la familia").tag("Family")
                    Text("Un grupo de personas (empresa, club, etc.)").tag("Group")
                }
                .pickerStyle(SegmentedPickerStyle())

                let groupLabel = moniker == "Family" ? "Nombre del hogar" : "Nombre del grupo"
                TextField(groupLabel, text: $familyName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)

            TextField("País (código)", text: $country)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
    }

    private var stepTwo: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading) {
                Text("Tema de color").font(.caption).foregroundColor(.secondary)
                Picker("Tema de color", selection: $theme) {
                    Text("Sistema").tag("system")
                    Text("Claro").tag("light")
                    Text("Oscuro").tag("dark")
                }
                .pickerStyle(MenuPickerStyle())
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(8)
            }

            VStack(alignment: .leading) {
                Text("Idioma").font(.caption).foregroundColor(.secondary)
                Picker("Idioma", selection: $locale) {
                    Text("Español").tag("es")
                    Text("English").tag("en")
                }
                .pickerStyle(MenuPickerStyle())
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(8)
            }

            VStack(alignment: .leading) {
                Text("Moneda").font(.caption).foregroundColor(.secondary)
                Picker("Moneda", selection: $currency) {
                    Text("Guaraní (PYG)").tag("PYG")
                    Text("Dólar (USD)").tag("USD")
                    Text("Peso Argentino (ARS)").tag("ARS")
                    Text("Real (BRL)").tag("BRL")
                    Text("Euro (EUR)").tag("EUR")
                }
                .pickerStyle(MenuPickerStyle())
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(8)
            }

            VStack(alignment: .leading) {
                Text("Formato de fecha").font(.caption).foregroundColor(.secondary)
                Picker("Formato de fecha", selection: $dateFormat) {
                    Text("DD/MM/YYYY").tag("%d/%m/%Y")
                    Text("YYYY-MM-DD").tag("%Y-%m-%d")
                    Text("MM/DD/YYYY").tag("%m/%d/%Y")
                }
                .pickerStyle(MenuPickerStyle())
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(8)
            }
        }
    }

    private var stepThree: some View {
        VStack(spacing: 12) {
            ForEach(GOAL_OPTIONS) { option in
                let isSelected = selectedGoals.contains(option.id)
                Button(action: {
                    if isSelected {
                        selectedGoals.remove(option.id)
                    } else {
                        selectedGoals.insert(option.id)
                    }
                }) {
                    HStack {
                        Text(option.title)
                            .fontWeight(isSelected ? .bold : .regular)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                        Spacer()
                        if isSelected {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(isSelected ? Color.blue.opacity(0.1) : Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1)
                    )
                }
            }
        }
    }

    private func completeOnboarding() {
        isLoading = true
        errorMessage = nil

        let body = UpdateUserBody(
            firstName: firstName.isEmpty ? nil : firstName,
            lastName: lastName.isEmpty ? nil : lastName,
            theme: theme,
            locale: locale,
            goals: Array(selectedGoals),
            setOnboardingPreferencesAt: nil, // Can be sent by the server, but we will send the full payload
            setOnboardingGoalsAt: nil,
            onboardedAt: ISO8601DateFormatter().string(from: Date()), // Mark as onboarded
            familyAttributes: UpdateFamilyAttributesDto(
                moniker: moniker,
                name: familyName.isEmpty ? nil : familyName,
                country: country.isEmpty ? nil : country,
                currency: currency,
                locale: locale,
                dateFormat: dateFormat
            )
        )

        Task {
            do {
                _ = try await FinancePyApi.shared.updateUser(body: body)
                DispatchQueue.main.async {
                    onComplete()
                }
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(onComplete: {})
    }
}
