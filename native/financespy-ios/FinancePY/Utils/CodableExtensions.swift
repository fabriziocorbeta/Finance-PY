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
