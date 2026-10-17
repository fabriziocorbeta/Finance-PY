import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct UpayImportView: View {
    @StateObject private var viewModel = UpayImportViewModel()
    @Query(sort: \AccountEntity.name) private var accounts: [AccountEntity]

    @State private var isFilePickerPresented = false

    var body: some View {
        VStack {
            switch viewModel.step {
            case .pick, .uploading:
                pickStepView
            case .result:
                resultStepView
            }
        }
        .navigationTitle("Importar liquidación Upay")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $isFilePickerPresented,
            allowedContentTypes: [UTType.commaSeparatedText],
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
                Text("Subí el CSV que exporta Upay con las liquidaciones de tarjeta. Se registra el ingreso y la comisión automáticamente, y se concilia con ventas ya cargadas cuando coinciden.")
                    .font(.body)
                    .foregroundColor(.secondary)

                if let error = viewModel.error {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.body)
                }

                VStack(alignment: .leading) {
                    Text("Cuenta de depósito")
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
                        Text(viewModel.pickedFileName ?? "Seleccionar archivo CSV")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
                }
                .disabled(viewModel.step == .uploading)

                Button(action: {
                    viewModel.upload()
                }) {
                    if viewModel.step == .uploading {
                        ProgressView()
                    } else {
                        Text("Subir y procesar")
                    }
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .disabled(viewModel.step == .uploading || viewModel.pickedFileData == nil || viewModel.selectedAccountId.isEmpty)

                if viewModel.step == .uploading {
                    HStack {
                        Text("Procesando la liquidación…")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)
                }
            }
            .padding()
        }
    }

    private var resultStepView: some View {
        VStack(spacing: 16) {
            if let result = viewModel.result {
                if result.status == "finished" || result.status == "published" {
                    Image(systemName: "checkmark.circle.fill")
                        .resizable()
                        .frame(width: 60, height: 60)
                        .foregroundColor(.green)

                    Text("Importación exitosa")
                        .font(.title2)
                        .fontWeight(.semibold)

                    if let stats = result.stats {
                        VStack(spacing: 8) {
                            Text("Total de filas: \(stats.rowsCount)")
                            Text("Válidas: \(stats.validRowsCount)")
                                .foregroundColor(.green)
                            Text("Inválidas: \(stats.invalidRowsCount)")
                                .foregroundColor(stats.invalidRowsCount > 0 ? .red : .secondary)
                        }
                        .font(.body)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                    }

                } else {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .resizable()
                        .frame(width: 60, height: 60)
                        .foregroundColor(.red)

                    Text("Importación con errores")
                        .font(.title2)
                        .fontWeight(.semibold)

                    if let errorMsg = result.error {
                        Text(errorMsg)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                }
            }

            Button(action: {
                viewModel.reset()
            }) {
                Text("Importar otro")
            }
            .buttonStyle(.bordered)
            .padding(.top, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
