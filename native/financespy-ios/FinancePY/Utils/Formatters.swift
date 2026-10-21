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

    static func formatMoney(_ money: MoneyDto) -> String {
        if let formatted = money.formatted, !formatted.isEmpty {
            return formatted
        } else if let cents = money.cents {
            return formatCents(cents, currency: money.currency ?? "PYG")
        } else if let amount = money.amount, let currency = money.currency {
            return "\(currency) \(amount)"
        } else {
            return "--"
        }
    }
}

// MARK: - Display labels

extension Formatters {
    // The API sends `accountable_type.underscore` ("credit_card", "other_liability");
    // ignoring underscores/case also covers the CamelCase form used on writes.
    // Same labels as config/locales/views/accounts/es.yml (accounts.types.*), which the
    // web balance sheet shows, so an account has the same type name on web and iOS.
    static func accountTypeLabel(_ raw: String) -> String {
        switch raw.replacingOccurrences(of: "_", with: "").lowercased() {
        case "depository": return "Efectivo"
        case "creditcard": return "Tarjeta de crédito"
        case "loan": return "Préstamo"
        case "investment": return "Inversión"
        case "crypto": return "Cripto"
        case "property": return "Propiedad"
        case "vehicle": return "Vehículo"
        case "otherasset": return "Otro activo"
        case "otherliability": return "Otra deuda"
        case "receivable": return "Cuenta por cobrar"
        default: return humanize(raw)
        }
    }

    // Same labels as config/locales/views/sales/es.yml (sales.status.*).
    static func saleStatusLabel(_ raw: String) -> String {
        switch raw {
        case "draft": return "Borrador"
        case "completed": return "Completada"
        case "cancelled": return "Cancelada"
        default: return humanize(raw)
        }
    }

    // Same labels as config/locales/views/purchase_orders/es.yml (purchase_orders.status.*).
    static func purchaseOrderStatusLabel(_ raw: String) -> String {
        switch raw {
        case "draft": return "Borrador"
        case "received": return "Recibido"
        case "cancelled": return "Cancelado"
        default: return humanize(raw)
        }
    }

    // "other_thing" / "OtherThing" -> "Other thing"
    static func humanize(_ raw: String) -> String {
        var spaced = ""
        var previous: Character?
        for char in raw {
            if char == "_" || char == "-" {
                spaced.append(" ")
            } else {
                if char.isUppercase, previous?.isLowercase == true {
                    spaced.append(" ")
                }
                spaced.append(char)
            }
            previous = char
        }
        let words = spaced.split(separator: " ").joined(separator: " ").lowercased()
        return words.prefix(1).uppercased() + words.dropFirst()
    }
}

// MARK: - Dates

extension Formatters {
    static let displayLocale = Locale(identifier: "es_PY")

    // Date-only values ("2026-11-05") are calendar days, not instants: parse and
    // print them in UTC so the device time zone can never shift them by a day.
    private static let dayParser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let dayDisplay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = displayLocale
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private static let instantDisplay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = displayLocale
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private static let isoParser: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let isoFractionalParser: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    /// "2026-11-05" or an ISO8601 timestamp -> "5 nov 2026"; anything unparsable comes back as-is.
    static func formatDate(_ raw: String) -> String {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.count == 10, let day = dayParser.date(from: value) {
            return dayDisplay.string(from: day)
        }
        if let instant = isoFractionalParser.date(from: value) ?? isoParser.date(from: value) {
            return instantDisplay.string(from: instant)
        }
        return raw
    }
}
