import Foundation
import Combine

enum PdfImportStep {
    case pick
    case processing
    case review
    case done
}

@MainActor
class PdfStatementImportViewModel: ObservableObject {
    @Published var step: PdfImportStep = .pick
    @Published var selectedAccountId: String = ""
    @Published var pickedFileName: String? = nil
    @Published var pickedFileData: Data? = nil
    @Published var isBusy: Bool = false
    @Published var importId: String? = nil
    @Published var rows: [PdfImportRowDto] = []
    @Published var error: String? = nil

    private let api = ApiClient.shared
    private var pollingTask: Task<Void, Never>? = nil

    func onFilePicked(data: Data, fileName: String) {
        self.pickedFileData = data
        self.pickedFileName = fileName
        self.error = nil
    }

    func upload() {
        guard !selectedAccountId.isEmpty else {
            self.error = "Seleccioná una cuenta"
            return
        }

        guard let data = pickedFileData, let fileName = pickedFileName else {
            self.error = "Seleccioná el PDF del extracto"
            return
        }

        isBusy = true
        error = nil
        step = .processing

        Task {
            do {
                let result = try await api.uploadPdfStatement(accountId: selectedAccountId, fileData: data, fileName: fileName)
                self.importId = result.id
                pollUntilReviewable(importId: result.id)
            } catch {
                self.isBusy = false
                self.error = error.localizedDescription
                self.step = .pick
            }
        }
    }

    private func pollUntilReviewable(importId: String) {
        pollingTask?.cancel()
        pollingTask = Task {
            while !Task.isCancelled {
                do {
                    let result = try await api.fetchImport(importId: importId)

                    if result.status == "reviewable" {
                        let fetchedRows = try await api.fetchPdfImportRows(importId: importId)
                        self.rows = fetchedRows
                        self.isBusy = false
                        self.step = .review
                        break
                    } else if result.status == "error" || result.status == "failed" {
                        self.error = result.error ?? "Ocurrió un error al procesar el archivo"
                        self.isBusy = false
                        self.step = .pick
                        break
                    }

                    // Delay before next poll (e.g. 5 seconds)
                    try await Task.sleep(nanoseconds: 5_000_000_000)
                } catch {
                    if !Task.isCancelled {
                        self.error = error.localizedDescription
                        self.isBusy = false
                        self.step = .pick
                        break
                    }
                }
            }
        }
    }

    func confirm() {
        guard let importId = importId else { return }

        isBusy = true
        error = nil

        Task {
            do {
                try await api.publishImport(importId: importId)
                self.isBusy = false
                self.step = .done
            } catch {
                self.isBusy = false
                self.error = error.localizedDescription
            }
        }
    }

    func reset() {
        self.step = .pick
        self.pickedFileName = nil
        self.pickedFileData = nil
        self.isBusy = false
        self.importId = nil
        self.rows = []
        self.error = nil
    }
}
