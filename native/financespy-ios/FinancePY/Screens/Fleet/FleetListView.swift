import SwiftUI

struct FleetListView: View {
    @StateObject private var viewModel = FleetListViewModel()
    @State private var showAddDialog = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                if viewModel.isLoading && viewModel.vehicles.isEmpty {
                    ProgressView()
                } else if let error = viewModel.error {
                    VStack(spacing: 16) {
                        Text(error)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding()

                        Button("Reintentar") {
                            Task {
                                await viewModel.fetchVehicles()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else if viewModel.vehicles.isEmpty {
                    VStack {
                        Text("No hay vehículos en la flota todavía. Agrega uno nuevo para comenzar a llevar el registro.")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                } else {
                    List {
                        ForEach(viewModel.vehicles) { vehicle in
                            NavigationLink(destination: FleetVehicleDetailView(vehicleId: vehicle.id)) {
                                FleetVehicleCard(vehicle: vehicle)
                            }
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Flota")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddDialog = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .task {
                await viewModel.fetchVehicles()
            }
            .refreshable {
                await viewModel.fetchVehicles()
            }
            .sheet(isPresented: $showAddDialog) {
                AddVehicleView { plate, brand, model, year, status, notes in
                    Task {
                        await viewModel.createVehicle(
                            plate: plate,
                            brand: brand,
                            model: model,
                            year: year,
                            status: status,
                            notes: notes
                        )
                        showAddDialog = false
                    }
                }
            }
        }
    }
}

struct FleetVehicleCard: View {
    let vehicle: FleetVehicleDto

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(vehicle.plate)
                    .font(.title3)
                    .fontWeight(.bold)

                Spacer()

                StatusBadge(status: vehicle.status)
            }

            Text("\(vehicle.brand) \(vehicle.model)\(vehicle.year != null ? " (\(vehicle.year!))" : "")")
                .font(.body)
                .foregroundColor(.secondary)

            if let notes = vehicle.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
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

class FleetListViewModel: ObservableObject {
    @Published var vehicles: [FleetVehicleDto] = []
    @Published var isLoading = false
    @Published var error: String?

    private let api = FinancePyApi.shared

    @MainActor
    func fetchVehicles() async {
        isLoading = true
        error = nil

        do {
            vehicles = try await api.fetchFleetVehicles()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    @MainActor
    func createVehicle(plate: String, brand: String, model: String, year: Int?, status: String, notes: String?) async {
        let request = CreateFleetVehicleRequest(
            fleetVehicle: CreateFleetVehicleBody(
                plate: plate,
                brand: brand,
                model: model,
                year: year,
                status: status,
                notes: notes
            )
        )

        do {
            let _ = try await api.createFleetVehicle(request: request)
            await fetchVehicles()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct AddVehicleView: View {
    @Environment(\.dismiss) var dismiss

    @State private var plate = ""
    @State private var brand = ""
    @State private var model = ""
    @State private var yearText = ""
    @State private var notes = ""

    let onConfirm: (String, String, String, Int?, String, String?) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Información del Vehículo")) {
                    TextField("Chapa / Matrícula", text: $plate)
                    TextField("Marca", text: $brand)
                    TextField("Modelo", text: $model)
                    TextField("Año (opcional)", text: $yearText)
                        .keyboardType(.numberPad)
                    TextField("Notas (opcional)", text: $notes)
                }
            }
            .navigationTitle("Nuevo Vehículo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Guardar") {
                        let year = Int(yearText)
                        onConfirm(
                            plate,
                            brand,
                            model,
                            year,
                            "active",
                            notes.isEmpty ? nil : notes
                        )
                    }
                    .disabled(plate.isEmpty || brand.isEmpty || model.isEmpty)
                }
            }
        }
    }
}
