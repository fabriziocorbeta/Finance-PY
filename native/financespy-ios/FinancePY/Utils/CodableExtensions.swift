import Foundation

@propertyWrapper
struct AnyStringAmount: Codable, Hashable {
    var wrappedValue: String?

    init(wrappedValue: String? = nil) {
        self.wrappedValue = wrappedValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self.wrappedValue = nil
        } else if let intValue = try? container.decode(Int64.self) {
            self.wrappedValue = String(intValue)
        } else if let doubleValue = try? container.decode(Double.self) {
            self.wrappedValue = String(doubleValue)
        } else if let stringValue = try? container.decode(String.self) {
            self.wrappedValue = stringValue
        } else {
            self.wrappedValue = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wrappedValue)
    }
}

extension KeyedDecodingContainer {
    func decode(_ type: AnyStringAmount.Type, forKey key: Key) throws -> AnyStringAmount {
        if let value = try decodeIfPresent(type, forKey: key) {
            return value
        }
        return AnyStringAmount(wrappedValue: nil)
    }
}

// MARK: - Numeric wrappers tolerant to Rails BigDecimal-as-String

private enum FlexibleNumber {
    static func double(from value: String) -> Double? {
        let s = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        let normalized: String
        if s.contains(",") && s.contains(".") {
            normalized = s.lastIndex(of: ",")! > s.lastIndex(of: ".")!
                ? s.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
                : s.replacingOccurrences(of: ",", with: "")
        } else {
            normalized = s.replacingOccurrences(of: ",", with: ".")
        }
        guard let d = Double(normalized), d.isFinite else { return nil }
        return d
    }

    static func double(from container: SingleValueDecodingContainer) -> Double? {
        if container.decodeNil() { return nil }
        if let d = try? container.decode(Double.self) { return d.isFinite ? d : nil }
        if let s = try? container.decode(String.self) { return double(from: s) }
        return nil
    }
}

/// Non-optional Double accepting number or numeric String (defaults to 0).
@propertyWrapper
struct FlexibleDouble: Codable, Hashable {
    var wrappedValue: Double
    init(wrappedValue: Double = 0) { self.wrappedValue = wrappedValue }
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        wrappedValue = FlexibleNumber.double(from: c) ?? 0
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(wrappedValue)
    }
}

/// Optional Double accepting number, numeric String or null.
@propertyWrapper
struct OptionalFlexibleDouble: Codable, Hashable {
    var wrappedValue: Double?
    init(wrappedValue: Double? = nil) { self.wrappedValue = wrappedValue }
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        wrappedValue = FlexibleNumber.double(from: c)
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(wrappedValue)
    }
}

/// `[String: Double]?` accepting values as numbers or numeric Strings; tolerates null/[]/garbage.
@propertyWrapper
struct OptionalFlexibleDoubleDictionary: Codable, Hashable {
    var wrappedValue: [String: Double]?
    init(wrappedValue: [String: Double]? = nil) { self.wrappedValue = wrappedValue }
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { wrappedValue = nil; return }
        if let dict = try? c.decode([String: OptionalFlexibleDouble].self) {
            wrappedValue = dict.compactMapValues { $0.wrappedValue }
        } else {
            wrappedValue = nil
        }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(wrappedValue)
    }
}

extension KeyedDecodingContainer {
    func decode(_ type: FlexibleDouble.Type, forKey key: Key) throws -> FlexibleDouble {
        (try? decodeIfPresent(type, forKey: key)) ?? FlexibleDouble()
    }
    func decode(_ type: OptionalFlexibleDouble.Type, forKey key: Key) throws -> OptionalFlexibleDouble {
        (try? decodeIfPresent(type, forKey: key)) ?? OptionalFlexibleDouble()
    }
    func decode(_ type: OptionalFlexibleDoubleDictionary.Type, forKey key: Key) throws -> OptionalFlexibleDoubleDictionary {
        (try? decodeIfPresent(type, forKey: key)) ?? OptionalFlexibleDoubleDictionary()
    }
}

/// Non-optional String id that tolerates `null` or numeric values (e.g. Budget not yet persisted -> `id: null`).
@propertyWrapper
struct NullableID: Codable, Hashable {
    var wrappedValue: String
    init(wrappedValue: String = "") { self.wrappedValue = wrappedValue }
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { wrappedValue = ""; return }
        if let s = try? c.decode(String.self) { wrappedValue = s }
        else if let i = try? c.decode(Int64.self) { wrappedValue = String(i) }
        else { wrappedValue = "" }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(wrappedValue)
    }
}

extension KeyedDecodingContainer {
    func decode(_ type: NullableID.Type, forKey key: Key) throws -> NullableID {
        (try? decodeIfPresent(type, forKey: key)) ?? NullableID()
    }
}

/// Optional String that tolerates number/bool/array/object payloads (e.g. rule condition `value`).
@propertyWrapper
struct OptionalFlexibleString: Codable, Hashable {
    var wrappedValue: String?
    init(wrappedValue: String? = nil) { self.wrappedValue = wrappedValue }
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { wrappedValue = nil }
        else if let s = try? c.decode(String.self) { wrappedValue = s }
        else if let i = try? c.decode(Int64.self) { wrappedValue = String(i) }
        else if let d = try? c.decode(Double.self) { wrappedValue = String(d) }
        else if let b = try? c.decode(Bool.self) { wrappedValue = String(b) }
        else { wrappedValue = nil }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(wrappedValue)
    }
}

extension KeyedDecodingContainer {
    func decode(_ type: OptionalFlexibleString.Type, forKey key: Key) throws -> OptionalFlexibleString {
        (try? decodeIfPresent(type, forKey: key)) ?? OptionalFlexibleString()
    }
}

/// Logs the exact key/path of a JSON contract mismatch (DEBUG only) so
/// decoding failures can be diagnosed from the console.
enum DecodingDiagnostics {
    static func log(_ error: Error, type: Any.Type, path: String) {
        #if DEBUG
        func p(_ ctx: DecodingError.Context, _ extra: CodingKey? = nil) -> String {
            (ctx.codingPath + (extra.map { [$0] } ?? [])).map(\.stringValue).joined(separator: ".")
        }
        switch error {
        case let DecodingError.keyNotFound(key, ctx):
            print("🚨 [Decode KeyNotFound] \(path) | \(type) | key: '\(p(ctx, key))' | \(ctx.debugDescription)")
        case let DecodingError.typeMismatch(expected, ctx):
            print("🚨 [Decode TypeMismatch] \(path) | \(type) | at: '\(p(ctx))' | expected: \(expected) | \(ctx.debugDescription)")
        case let DecodingError.valueNotFound(expected, ctx):
            print("🚨 [Decode ValueNotFound(null)] \(path) | \(type) | at: '\(p(ctx))' | expected: \(expected)")
        default:
            print("🚨 [Decode Error] \(path) | \(type) | \(error)")
        }
        #endif
    }
}
