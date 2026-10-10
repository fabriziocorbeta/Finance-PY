import Foundation
import Combine

@MainActor
class ReportsViewModel: ObservableObject {
    @Published var summary: ReportsSummaryDto?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    @Published var periodType: String = "monthly" // "monthly", "custom"

    // For custom dates
    @Published var startDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @Published var endDate: Date = Date()

    private var cancellables = Set<AnyCancellable>()

    init() {
        // Automatically fetch when period changes, if using Combine
        $periodType
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] _ in
                Task {
                    await self?.fetchReports()
                }
            }
            .store(in: &cancellables)
    }

    func fetchReports() async {
        isLoading = true
        errorMessage = nil

        do {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"

            var sDateStr: String? = nil
            var eDateStr: String? = nil

            if periodType == "custom" {
                sDateStr = formatter.string(from: startDate)
                eDateStr = formatter.string(from: endDate)
            }

            summary = try await FinancePyApi.shared.fetchReportsSummary(
                periodType: periodType,
                startDate: sDateStr,
                endDate: eDateStr
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
