import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct PdfStatementImportView: View {
    @StateObject private var viewModel = PdfStatementImportViewModel()
    @Query(sort: \AccountEntity.name) private var accounts: [AccountEntity]

    @State private var isFilePickerPresented = false

    var body: some View {
        VStack {
            switch viewModel.step {
            case .pick, .processing:
                pickStepView
            case .review:
                reviewStepView
            case .done:
                doneStepView
            }
        }
        .navigationTitle("Importar extracto")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $isFilePickerPresented,
            allowedContentTypes: [UTType.pdf],
            allowsMultipleSelection: false
        ) { result in
            do {
                guard let selectedFile: URL = try result.get().first else { return }

                if selectedFile.startAccessingSecurityScopedResource() {
                    defer { selectedFile.stopAccessingSecurityScopedResource() }
                    let fileData = try Data(contentsOf: selectedFile)
                    let fileName = selectedFile.lastPathComponent
                    viewModel.onFilePicked(data: fileData, fileName: fileName)
                } else {
                    viewModel.error = "No se pudo acceder al archivo seleccionado."
                }
            } catch {
                viewModel.error = error.localizedDescription
            }
        }
        .onAppear {
            if viewModel.selectedAccountId.isEmpty, let firstAccount = accounts.first {
                viewModel.selectedAccountId = firstAccount.id
            }
        }
    }

    private var pickStepView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Subí el PDF del extracto de tu banco o tarjeta de crédito. Una IA lee el documento y extrae las transacciones automáticamente -- vas a poder revisarlas antes de que se guarden.")
                    .font(.body)
                    .foregroundColor(.secondary)

                if let error = viewModel.error {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.body)
                }

                VStack(alignment: .leading) {
                    Text("Cuenta del extracto")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Picker("Cuenta", selection: $viewModel.selectedAccountId) {
                        ForEach(accounts) { account in
                            Text(account.name).tag(account.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
                }

                Button(action: {
                    isFilePickerPresented = true
                }) {
                    HStack {
                        Image(systemName: "doc.text")
                        Text(viewModel.pickedFileName ?? "Seleccionar PDF del extracto")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
                }
                .disabled(viewModel.isBusy)

                Button(action: {
                    viewModel.upload()
                }) {
                    if viewModel.isBusy && viewModel.step == .pick {
                        ProgressView()
                    } else {
                        Text("Subir y procesar con IA")
                    }
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .disabled(viewModel.isBusy || viewModel.pickedFileData == nil || viewModel.selectedAccountId.isEmpty)

                if viewModel.step == .processing {
                    HStack {
                        ProgressView()
                        Text("Leyendo el extracto con IA… puede tardar un minuto.")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)
                }
            }
            .padding()
        }
    }

    private var reviewStepView: some View {
        VStack {
            Text("\(viewModel.rows.count) transacciones encontradas. Revisá antes de confirmar -- la IA puede equivocarse.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding()

            if let error = viewModel.error {
                Text(error)
                    .foregroundColor(.red)
                    .font(.body)
                    .padding(.horizontal)
            }

            List(viewModel.rows) { row in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(row.fields.name ?? "(sin nombre)")
                            .font(.body)
                        Spacer()
                        Text(formatMoney(amountString: row.fields.amount, currency: row.fields.currency))
                            .font(.body)
                            .fontWeight(.medium)
                    }

                    Text("\(row.fields.date ?? "?")\(row.fields.category.map { " · \($0)" } ?? "")")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if !row.valid {
                        Text(row.errors.joined(separator: ", "))
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                .padding(.vertical, 4)
            }
            .listStyle(.plain)

            Button(action: {
                viewModel.confirm()
            }) {
                if viewModel.isBusy {
                    ProgressView()
                } else {
                    Text("Confirmar e importar \(viewModel.rows.count) transacciones")
                }
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
            .padding()
            .disabled(viewModel.isBusy)
        }
    }

    private var doneStepView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .resizable()
                .frame(width: 60, height: 60)
                .foregroundColor(.green)

            Text("Extracto importado")
                .font(.title2)
                .fontWeight(.semibold)

            Button(action: {
                viewModel.reset()
            }) {
                Text("Importar otro")
            }
            .buttonStyle(.bordered)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func formatMoney(amountString: String?, currency: String?) -> String {
        guard let amountStr = amountString, let amount = Double(amountStr) else {
            return "0.00"
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency ?? "PYG"
        return formatter.string(from: NSNumber(value: amount)) ?? "\(currency ?? "PYG") \(amount)"
    }
}
