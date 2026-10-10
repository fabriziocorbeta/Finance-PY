import Foundation

extension FinancePyApi {
    func fetchReportsSummary(periodType: String = "monthly", startDate: String? = nil, endDate: String? = nil) async throws -> ReportsSummaryDto {
        var queryItems = [URLQueryItem(name: "period_type", value: periodType)]

        if let startDate = startDate {
            queryItems.append(URLQueryItem(name: "start_date", value: startDate))
        }
        if let endDate = endDate {
            queryItems.append(URLQueryItem(name: "end_date", value: endDate))
        }

        return try await ApiClient.shared.request(path: "/api/v1/reports/summary", queryItems: queryItems)
    }
}
