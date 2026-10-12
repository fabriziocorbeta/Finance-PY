import Foundation

enum Formatters {
    static func centsToDouble(_ cents: Int64, currency: String) -> Double {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        let fractionDigits = formatter.maximumFractionDigits
        let divisor = pow(10.0, Double(fractionDigits))
        return Double(cents) / divisor
    }

    static func doubleToCents(_ amount: Double, currency: String) -> Int64 {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        let fractionDigits = formatter.maximumFractionDigits
        let multiplier = pow(10.0, Double(fractionDigits))
        return Int64(round(amount * multiplier))
    }

    static func formatCents(_ cents: Int64, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        let amount = centsToDouble(cents, currency: currency)
        return formatter.string(from: NSNumber(value: amount)) ?? "\(currency) \(amount)"
    }
}
