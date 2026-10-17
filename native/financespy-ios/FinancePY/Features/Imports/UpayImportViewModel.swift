import Foundation
import Combine

enum UpayImportStep {
    case pick
    case uploading
    case result
}

@MainActor
class UpayImportViewModel: ObservableObject {
    @Published var step: UpayImportStep = .pick
    @Published var selectedAccountId: String = ""
    @Published var pickedFileName: String? = nil
    @Published var pickedFileData: Data? = nil
    @Published var result: UpayImportResultDto? = nil
    @Published var error: String? = nil

    private let api = ApiClient.shared
    private var pollingTask: Task<Void, Never>? = nil

    func onFilePicked(data: Data, fileName: String) {
        self.pickedFileData = data
        self.pickedFileName = fileName
        self.result = nil
        self.error = nil
    }

    func upload() {
        guard !selectedAccountId.isEmpty else {
            self.error = "Seleccioná una cuenta"
            return
        }

        guard let data = pickedFileData, let fileName = pickedFileName else {
            self.error = "Seleccioná el archivo CSV"
            return
        }

        step = .uploading
        error = nil

        Task {
            do {
                let initialResult = try await api.uploadUpayImport(accountId: selectedAccountId, fileData: data, fileName: fileName)

                // If it's importing, poll until done.
                if initialResult.status == "importing" {
                    pollUntilDone(importId: initialResult.id)
                } else {
                    self.result = initialResult
                    self.step = .result
                }
            } catch {
                self.error = error.localizedDescription
                self.step = .pick
            }
        }
    }

    private func pollUntilDone(importId: String) {
        pollingTask?.cancel()
        pollingTask = Task {
            var attempts = 0
            while !Task.isCancelled && attempts < 10 { // limit polling attempts
                do {
                    let currentResult = try await api.fetchImport(importId: importId)

                    if currentResult.status == "finished" || currentResult.status == "failed" || currentResult.status == "error" {
                        self.result = currentResult
                        self.step = .result
                        break
                    }

                    attempts += 1
                    // Delay before next poll (e.g. 2 seconds)
                    try await Task.sleep(nanoseconds: 2_000_000_000)
                } catch {
                    if !Task.isCancelled {
                        self.error = error.localizedDescription
                        self.step = .pick
                        break
                    }
                }
            }

            // If we fall out of loop without setting step, it timed out or hit attempt limit
            if self.step == .uploading {
                // Fetch one last time to be safe, or just show whatever state we have
                do {
                    let finalResult = try await api.fetchImport(importId: importId)
                    self.result = finalResult
                    self.step = .result
                } catch {
                    self.error = "Tiempo de espera agotado al consultar el estado"
                    self.step = .pick
                }
            }
        }
    }

    func reset() {
        self.step = .pick
        self.pickedFileName = nil
        self.pickedFileData = nil
        self.result = nil
        self.error = nil
    }
}
