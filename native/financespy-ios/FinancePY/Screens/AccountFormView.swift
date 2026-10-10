import SwiftUI
import SwiftData

struct AccountFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let accountTypes = [
        ("Depository", "Cuenta bancaria / Efectivo"),
        ("CreditCard", "Tarjeta de crédito"),
        ("Investment", "Inversión"),
        ("Vehicle", "Vehículo"),
        ("Loan", "Préstamo"),
        ("Crypto", "Criptomoneda"),
        ("OtherAsset", "Otro activo")
    ]

    @State private var accountableType = "Depository"
    @State private var name = ""
    @State private var balance = ""
    @State private var currency = "PYG"
    @State private var institutionName = ""
    @State private var notes = ""

    // Type specific fields
    @State private var availableCredit = ""
    @State private var apr = ""
    @State private var vehicleMake = ""
    @State private var vehicleModel = ""
    @State private var vehicleYear = ""
    @State private var interestRate = ""
    @State private var termMonths = ""
    @State private var investmentSubtype = ""

    @State private var isSaving = false
    @State private var error: String? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Información básica")) {
                    Picker("Tipo de cuenta", selection: $accountableType) {
                        ForEach(accountTypes, id: \.0) { type, label in
                            Text(label).tag(type)
                        }
                    }

                    TextField("Nombre de la cuenta", text: $name)

                    TextField("Saldo inicial", text: $balance)
                        .keyboardType(.decimalPad)

                    TextField("Moneda", text: $currency)
                        .textInputAutocapitalization(.characters)
                }

                Section(header: Text("Detalles (Opcional)")) {
                    TextField("Institución financiera", text: $institutionName)
                    TextField("Notas", text: $notes)
                }

                // Dynamic sections based on account type
                if accountableType == "CreditCard" {
                    Section(header: Text("Detalles de Tarjeta")) {
                        TextField("Línea de crédito disponible", text: $availableCredit)
                            .keyboardType(.decimalPad)
                        TextField("Tasa de interés (APR %)", text: $apr)
                            .keyboardType(.decimalPad)
                    }
                } else if accountableType == "Vehicle" {
                    Section(header: Text("Detalles del Vehículo")) {
                        TextField("Marca", text: $vehicleMake)
                        TextField("Modelo", text: $vehicleModel)
                        TextField("Año", text: $vehicleYear)
                            .keyboardType(.numberPad)
                    }
                } else if accountableType == "Loan" {
                    Section(header: Text("Detalles del Préstamo")) {
                        TextField("Tasa de interés (%)", text: $interestRate)
                            .keyboardType(.decimalPad)
                        TextField("Plazo (meses)", text: $termMonths)
                            .keyboardType(.numberPad)
                    }
                } else if accountableType == "Investment" {
                    Section(header: Text("Detalles de Inversión")) {
                        TextField("Subtipo", text: $investmentSubtype)
                    }
                }

                if let error = error {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Nueva Cuenta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        Task { await saveAccount() }
                    }
                    .disabled(isSaving)
                }
            }
        }
    }

    private func saveAccount() async {
        guard !name.isEmpty else {
            error = "El nombre es obligatorio"
            return
        }

        guard let balanceValue = Double(balance) else {
            error = "El saldo inicial debe ser un número válido"
            return
        }

        isSaving = true
        error = nil

        var attrs: CreateAccountAccountableAttributes? = nil

        if accountableType == "CreditCard" {
            attrs = CreateAccountAccountableAttributes(
                availableCredit: Double(availableCredit),
                apr: Double(apr),
                make: nil, model: nil, year: nil, interestRate: nil, termMonths: nil, subtype: nil
            )
        } else if accountableType == "Vehicle" {
            attrs = CreateAccountAccountableAttributes(
                availableCredit: nil, apr: nil,
                make: vehicleMake.isEmpty ? nil : vehicleMake,
                model: vehicleModel.isEmpty ? nil : vehicleModel,
                year: Int(vehicleYear),
                interestRate: nil, termMonths: nil, subtype: nil
            )
        } else if accountableType == "Loan" {
            attrs = CreateAccountAccountableAttributes(
                availableCredit: nil, apr: nil, make: nil, model: nil, year: nil,
                interestRate: Double(interestRate),
                termMonths: Int(termMonths),
                subtype: nil
            )
        } else if accountableType == "Investment" {
            attrs = CreateAccountAccountableAttributes(
                availableCredit: nil, apr: nil, make: nil, model: nil, year: nil, interestRate: nil, termMonths: nil,
                subtype: investmentSubtype.isEmpty ? nil : investmentSubtype
            )
        }

        let body = CreateAccountBody(
            accountableType: accountableType,
            name: name,
            balance: balanceValue,
            currency: currency.isEmpty ? "PYG" : currency.uppercased(),
            institutionName: institutionName.isEmpty ? nil : institutionName,
            notes: notes.isEmpty ? nil : notes,
            accountableAttributes: attrs
        )

        do {
            let created = try await FinancePyApi.shared.createAccount(body: body)

            let entity = AccountEntity(
                id: created.id,
                name: created.name,
                balanceCents: created.balanceCents,
                cashBalanceCents: created.cashBalanceCents,
                currency: created.currency,
                classification: created.classification,
                accountType: created.accountType,
                subtype: created.subtype,
                status: created.status,
                updatedAt: created.updatedAt
            )

            modelContext.insert(entity)
            try modelContext.save()

            dismiss()
        } catch {
            self.error = error.localizedDescription
            isSaving = false
        }
    }
}
