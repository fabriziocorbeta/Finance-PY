import SwiftUI
import SwiftData
import UniformTypeIdentifiers

enum ImportKind: String, CaseIterable, Identifiable {
    case pdf = "Extracto PDF"
    case upay = "Liquidación Upay"

    var id: String { rawValue }
}

struct ImportsView: View {
    @Query(sort: \AccountEntity.name) private var accounts: [AccountEntity]

    @State private var kind: ImportKind = .pdf
    @State private var accountId: String = ""
    @State private var pickedFileName: String?
    @State private var pickedFileData: Data?
    @State private var showFileImporter = false

    @State private var isUploading = false
    @State private var error: String?

    // PDF review flow
    @State private var isPolling = false
    @State private var pdfImportId: String?
    @State private var pdfRows: [PdfImportRowDto] = []
    @State private var isConfirming = false

    // Upay result flow
    @State private var upayResult: ImportResultDto?

    var body: some View {
        NavigationStack {
            Form {
                if !pdfRows.isEmpty {
                    pdfReviewSection
                } else {
                    pickerSection
                }
            }
            .navigationTitle("Importaciones")
            .alert("Error", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(error ?? "")
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: kind == .pdf ? [.pdf] : [.commaSeparatedText, .plainText],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
        }
    }

    private var pickerSection: some View {
        Group {
            Section {
                Picker("Tipo", selection: $kind) {
                    ForEach(ImportKind.allCases) { k in
                        Text(k.rawValue).tag(k)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: kind) { _, _ in
                    pickedFileName = nil
                    pickedFileData = nil
                    upayResult = nil
                }
            }

            Section(header: Text("Cuenta")) {
                Picker("Cuenta", selection: $accountId) {
                    Text("Seleccionar cuenta").tag("")
                    ForEach(accounts) { account in
                        Text(account.name).tag(account.id)
                    }
                }
            }

            Section(header: Text(kind == .pdf ? "Extracto (PDF)" : "Liquidación (CSV)")) {
                Button {
                    showFileImporter = true
                } label: {
                    HStack {
                        Image(systemName: "doc")
                        Text(pickedFileName ?? "Seleccionar archivo")
                            .foregroundColor(pickedFileName == nil ? .secondary : .primary)
                    }
                }
            }

            if let upayResult {
                Section(header: Text("Resultado")) {
                    upayResultView(upayResult)
                }
            }

            Section {
                if isUploading || isPolling {
                    HStack {
                        Spacer()
                        ProgressView(isPolling ? "Procesando extracto..." : "Subiendo...")
                        Spacer()
                    }
                } else {
                    Button("Subir") {
                        Task { await upload() }
                    }
                    .disabled(accountId.isEmpty || pickedFileData == nil)
                }
            }
        }
    }

    @ViewBuilder
    private func upayResultView(_ result: ImportResultDto) -> some View {
        if result.status == "failed" {
            Text(result.error ?? "No se pudo procesar la liquidación")
                .foregroundColor(.red)
        } else if let stats = result.stats {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(stats.rowsCount) filas, \(stats.validRowsCount) válidas, \(stats.invalidRowsCount) inválidas")
                Text("Estado: \(result.status)")
                    .foregroundColor(.secondary)
            }
        } else {
            Text("Estado: \(result.status)")
        }
    }

    private var pdfReviewSection: some View {
        Group {
            Section(header: Text("Revisión del extracto"), footer: Text("Confirmá para crear las transacciones. Las filas con errores no se importan.")) {
                ForEach(pdfRows) { row in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(row.fields.name ?? "(sin nombre)")
                                .font(.body)
                            Spacer()
                            if let amount = row.fields.amount {
                                Text(amount)
                                    .font(.body.monospacedDigit())
                            }
                        }
                        HStack {
                            if let date = row.fields.date {
                                Text(date)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            if let category = row.fields.category {
                                Text(category)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if !row.valid {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                        if !row.errors.isEmpty {
                            Text(row.errors.joined(separator: ", "))
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
            }

            Section {
                if isConfirming {
                    HStack {
                        Spacer()
                        ProgressView("Confirmando...")
                        Spacer()
                    }
                } else {
                    Button("Confirmar importación") {
                        Task { await confirmPdfImport() }
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Cancelar", role: .cancel) {
                        resetPdfFlow()
                    }
                }
            }
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else {
                error = "No se pudo acceder al archivo seleccionado"
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            do {
                pickedFileData = try Data(contentsOf: url)
                pickedFileName = url.lastPathComponent
            } catch {
                self.error = "No se pudo leer el archivo: \(error.localizedDescription)"
            }
        case .failure(let err):
            error = err.localizedDescription
        }
    }

    private func upload() async {
        guard let fileData = pickedFileData, let fileName = pickedFileName else { return }
        isUploading = true
        error = nil
        upayResult = nil
        defer { isUploading = false }

        do {
            switch kind {
            case .upay:
                var result = try await FinancePyApi.shared.uploadUpayImport(accountId: accountId, fileData: fileData, fileName: fileName)
                if result.status == "importing" {
                    try? await Task.sleep(nanoseconds: 2_500_000_000)
                    result = (try? await FinancePyApi.shared.fetchImport(id: result.id)) ?? result
                }
                upayResult = result
            case .pdf:
                let created = try await FinancePyApi.shared.uploadPdfStatement(accountId: accountId, fileData: fileData, fileName: fileName)
                pdfImportId = created.id
                isUploading = false
                await pollPdfImport(initial: created)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    // The AI extraction step runs async on the backend and can take anywhere
    // from a few seconds to over a minute depending on statement length --
    // this polls on a fixed interval rather than a single delayed re-check
    // (unlike Upay's one-shot poll), since there's no fixed upper bound on
    // how long it'll take.
    private func pollPdfImport(initial: ImportResultDto) async {
        isPolling = true
        defer { isPolling = false }

        var result = initial
        var attempts = 0
        // ~2 minutes of polling before giving up and telling the user to
        // check back later -- a real statement with many pages can take a
        // while, but this screen shouldn't spin forever if something's stuck.
        while attempts < 40 && (result.status == "importing" || (result.status == "pending" && (result.stats?.rowsCount ?? 0) == 0)) {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            result = (try? await FinancePyApi.shared.fetchImport(id: result.id)) ?? result
            attempts += 1
        }

        if result.status == "failed" {
            error = result.error ?? "No se pudo procesar el extracto"
            resetPdfFlow()
        } else if (result.stats?.rowsCount ?? 0) > 0 {
            pdfRows = (try? await FinancePyApi.shared.fetchPdfImportRows(id: result.id)) ?? []
        } else {
            error = "El extracto se sigue procesando. Probá de nuevo en un rato desde Importaciones."
            resetPdfFlow()
        }
    }

    private func confirmPdfImport() async {
        guard let pdfImportId else { return }
        isConfirming = true
        defer { isConfirming = false }
        do {
            _ = try await FinancePyApi.shared.publishImport(id: pdfImportId)
            resetPdfFlow()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func resetPdfFlow() {
        pdfRows = []
        pdfImportId = nil
        pickedFileData = nil
        pickedFileName = nil
    }
}
