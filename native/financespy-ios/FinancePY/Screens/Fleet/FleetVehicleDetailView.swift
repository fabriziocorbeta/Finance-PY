import SwiftUI
import SwiftData

struct FleetVehicleDetailView: View {
    let vehicleId: String
    @StateObject private var viewModel = FleetVehicleDetailViewModel()
    @State private var showAddFuelLogDialog = false
    @Environment(\.dismiss) var dismiss

    @Query(sort: \AccountEntity.name)
    private var accounts: [AccountEntity]

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            if viewModel.isLoading && viewModel.vehicle == nil {
                ProgressView()
            } else if let error = viewModel.error {
                VStack(spacing: 16) {
                    Text(error)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding()

                    Button("Reintentar") {
                        Task {
                            await viewModel.fetchVehicle(id: vehicleId)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if let vehicle = viewModel.vehicle {
                ScrollView {
                    VStack(spacing: 16) {
                        // Vehicle Info Card
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(vehicle.plate)
                                        .font(.title2)
                                        .fontWeight(.bold)

                                    Text("\(vehicle.brand) \(vehicle.model)\(vehicle.year != nil ? " (\(vehicle.year!))" : "")")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                StatusBadge(status: vehicle.status)
                            }

                            if let notes = vehicle.notes, !notes.isEmpty {
                                Text(notes)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)

                        // Fuel Logs
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Registros de Combustible")
                                    .font(.headline)
                                Spacer()
                                Button(action: { showAddFuelLogDialog = true }) {
                                    Text("Agregar")
                                }
                            }
                            .padding(.horizontal)

                            if let fuelLogs = vehicle.fuelLogs, !fuelLogs.isEmpty {
                                LazyVStack(spacing: 12) {
                                    ForEach(fuelLogs) { fuelLog in
                                        FuelLogCard(fuelLog: fuelLog) {
                                            Task {
                                                await viewModel.deleteFuelLog(vehicleId: vehicleId, logId: fuelLog.id)
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            } else {
                                Text("No hay registros de combustible.")
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
        .navigationTitle("Detalle del Vehículo")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("Eliminar", role: .destructive) {
                        Task {
                            await viewModel.deleteVehicle(id: vehicleId)
                            dismiss()
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .task {
            await viewModel.fetchVehicle(id: vehicleId)
        }
        .refreshable {
            await viewModel.fetchVehicle(id: vehicleId)
        }
        .sheet(isPresented: $showAddFuelLogDialog) {
            AddFuelLogView(accounts: accounts) { accountId, date, odometer, lines, notes in
                Task {
                    await viewModel.createFuelLog(
                        vehicleId: vehicleId,
                        accountId: accountId,
                        loggedAt: date,
                        odometer: odometer,
                        lines: lines,
                        notes: notes
                    )
                    showAddFuelLogDialog = false
                }
            }
        }
    }
}

private func StatusBadge(status: String) -> some View {
    let label: String
    let bgColor: Color
    let textColor: Color

    switch status.lowercased() {
    case "maintenance":
        label = "En Mantenimiento"
        bgColor = Color.orange.opacity(0.2)
        textColor = Color.orange
    case "inactive":
        label = "Inactivo"
        bgColor = Color(.systemGray5)
        textColor = .secondary
    default:
        label = "Activo"
        bgColor = Color.green.opacity(0.2)
        textColor = Color.green
    }

    return Text(label)
        .font(.caption)
        .fontWeight(.semibold)
        .foregroundColor(textColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(bgColor)
        .cornerRadius(16)
}

struct FuelLogCard: View {
    let fuelLog: FuelLogDto
    let onDelete: () -> Void
    @State private var showingDeleteAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(fuelLog.loggedAt)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text(formatMoney(cost: fuelLog.cost))
                    .font(.subheadline)
                    .fontWeight(.bold)
            }

            let linesSummary = (fuelLog.fuelLogLines ?? []).map { line in
                let brandStr = line.brand?.isEmpty == false ? " (\(line.brand!))" : ""
                return "\(formatDouble(line.liters)) L \(fuelTypeLabel(line.fuelType))\(brandStr)"
            }.joined(separator: ", ")

            Text(linesSummary.isEmpty ? "\(formatDouble(fuelLog.liters)) L" : linesSummary)
                .font(.caption)
                .foregroundColor(.secondary)

            if let odometer = fuelLog.odometer, odometer > 0 {
                Text("Km: \(formatDouble(odometer))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack {
                Spacer()
                Button(role: .destructive, action: { showingDeleteAlert = true }) {
                    Text("Eliminar")
                        .font(.caption)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .alert("¿Eliminar registro?", isPresented: $showingDeleteAlert) {
            Button("Cancelar", role: .cancel) { }
            Button("Eliminar", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Esta acción no se puede deshacer.")
        }
    }

    private func formatMoney(cost: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "PYG"
        return formatter.string(from: NSNumber(value: cost)) ?? "PYG \(cost)"
    }

    private func formatDouble(_ value: Double) -> String {
        return String(format: "%.1f", value)
    }

    private func fuelTypeLabel(_ type: String) -> String {
        switch type.lowercased() {
        case "nafta": return "Nafta"
        case "alcohol": return "Alcohol"
        case "gnc": return "GNC"
        case "diesel": return "Diesel"
        default: return type.capitalized
        }
    }
}

class FleetVehicleDetailViewModel: ObservableObject {
    @Published var vehicle: FleetVehicleDto?
    @Published var isLoading = false
    @Published var error: String?

    private let api = FinancePyApi.shared

    @MainActor
    func fetchVehicle(id: String) async {
        isLoading = true
        error = nil

        do {
            vehicle = try await api.fetchFleetVehicle(id: id)
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    @MainActor
    func deleteVehicle(id: String) async {
        isLoading = true
        error = nil

        do {
            try await api.deleteFleetVehicle(id: id)
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    @MainActor
    func createFuelLog(
        vehicleId: String,
        accountId: String,
        loggedAt: String,
        odometer: Double?,
        lines: [CreateFuelLogLineBody],
        notes: String?
    ) async {
        let totalLiters = lines.reduce(0) { $0 + $1.liters }
        let totalCost = lines.reduce(0) { $0 + $1.cost }

        let request = CreateFuelLogRequest(
            fuelLog: CreateFuelLogBody(
                accountId: accountId,
                loggedAt: loggedAt,
                odometer: odometer,
                liters: totalLiters,
                cost: totalCost,
                notes: notes,
                fuelLogLines: lines
            )
        )

        do {
            let _ = try await api.createFuelLog(vehicleId: vehicleId, request: request)
            await fetchVehicle(id: vehicleId)
        } catch {
            self.error = error.localizedDescription
        }
    }

    @MainActor
    func deleteFuelLog(vehicleId: String, logId: String) async {
        do {
            try await api.deleteFuelLog(vehicleId: vehicleId, logId: logId)
            await fetchVehicle(id: vehicleId)
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct FuelLogLineInput: Identifiable {
    let id = UUID()
    var fuelType: String = "nafta"
    var brand: String = "Podium"
    var litersText: String = ""
    var costText: String = ""
}

struct AddFuelLogView: View {
    let accounts: [AccountEntity]
    let onConfirm: (String, String, Double?, [CreateFuelLogLineBody], String?) -> Void

    @Environment(\.dismiss) var dismiss

    @State private var selectedAccountId = ""
    @State private var date = Date()
    @State private var odometerText = ""
    @State private var notes = ""

    @State private var lines: [FuelLogLineInput] = [FuelLogLineInput()]

    let fuelTypes = ["nafta", "alcohol", "gnc", "diesel"]

    func brandSuggestions(for type: String) -> [String] {
        switch type {
        case "nafta": return ["Podium", "Super 97", "Grid", "Prix"]
        case "diesel": return ["Podium", "Euro 6", "Euro 5"]
        default: return []
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Cuenta y Fecha")) {
                    Picker("Cuenta", selection: $selectedAccountId) {
                        Text("Seleccione cuenta").tag("")
                        ForEach(accounts) { account in
                            Text(account.name).tag(account.id)
                        }
                    }

                    DatePicker("Fecha", selection: $date, displayedComponents: .date)

                    TextField("Kilometraje (opcional)", text: $odometerText)
                        .keyboardType(.decimalPad)
                }

                ForEach($lines.indices, id: \.self) { index in
                    Section(header: HStack {
                        Text("Combustible \(index + 1)")
                        Spacer()
                        if lines.count > 1 {
                            Button(role: .destructive, action: {
                                lines.remove(at: index)
                            }) {
                                Image(systemName: "trash")
                            }
                        }
                    }) {
                        Picker("Tipo de Combustible", selection: $lines[index].fuelType) {
                            ForEach(fuelTypes, id: \.self) { type in
                                Text(type.capitalized).tag(type)
                            }
                        }
                        .onChange(of: lines[index].fuelType) { newValue in
                            lines[index].brand = newValue == "nafta" ? "Podium" : (newValue == "diesel" ? "Euro 6" : "")
                        }

                        let suggestions = brandSuggestions(for: lines[index].fuelType)
                        if !suggestions.isEmpty {
                            Picker("Marca / Grado", selection: $lines[index].brand) {
                                ForEach(suggestions, id: \.self) { suggestion in
                                    Text(suggestion).tag(suggestion)
                                }
                            }
                        } else {
                            TextField("Marca / Grado", text: $lines[index].brand)
                        }

                        TextField("Litros", text: $lines[index].litersText)
                            .keyboardType(.decimalPad)

                        TextField("Costo", text: $lines[index].costText)
                            .keyboardType(.decimalPad)
                    }
                }

                Section {
                    Button(action: {
                        lines.append(FuelLogLineInput())
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Agregar otro combustible")
                        }
                    }
                }

                Section(header: Text("Notas")) {
                    TextField("Notas (opcional)", text: $notes)
                }
            }
            .navigationTitle("Registro de Combustible")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Guardar") {
                        let formatter = ISO8601DateFormatter()
                        formatter.formatOptions = [.withFullDate]
                        let dateString = formatter.string(from: date)

                        let mappedLines = lines.compactMap { line -> CreateFuelLogLineBody? in
                            guard let liters = Double(line.litersText.replacingOccurrences(of: ",", with: ".")),
                                  let cost = Double(line.costText.replacingOccurrences(of: ",", with: ".")) else {
                                return nil
                            }
                            return CreateFuelLogLineBody(
                                fuelType: line.fuelType,
                                brand: line.brand.isEmpty ? nil : line.brand,
                                liters: liters,
                                cost: cost
                            )
                        }

                        onConfirm(
                            selectedAccountId,
                            dateString,
                            Double(odometerText.replacingOccurrences(of: ",", with: ".")),
                            mappedLines,
                            notes.isEmpty ? nil : notes
                        )
                    }
                    .disabled(
                        selectedAccountId.isEmpty ||
                        lines.contains { line in
                            Double(line.litersText.replacingOccurrences(of: ",", with: ".")) == nil ||
                            Double(line.costText.replacingOccurrences(of: ",", with: ".")) == nil
                        }
                    )
                }
            }
            .onAppear {
                if let first = accounts.first {
                    selectedAccountId = first.id
                }
            }
        }
    }
}
