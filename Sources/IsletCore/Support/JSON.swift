import Foundation

/// A forgiving read-only view over a decoded JSON object.
///
/// Both the Codex CLI and Claude Code evolve their on-disk transcript schemas between
/// releases, and neither is a documented public format. Strict `Codable` decoding would
/// throw away an entire record the moment an unexpected field appears, so we read fields
/// defensively and tolerate anything we do not recognise.
public struct JSONObject {
    public let raw: [String: Any]

    public init(_ raw: [String: Any]) {
        self.raw = raw
    }

    public init?(data: Data) {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        self.raw = object
    }

    public func object(_ key: String) -> JSONObject? {
        (raw[key] as? [String: Any]).map(JSONObject.init)
    }

    public func string(_ key: String) -> String? {
        raw[key] as? String
    }

    public func int(_ key: String) -> Int? {
        (raw[key] as? NSNumber)?.intValue
    }

    public func double(_ key: String) -> Double? {
        (raw[key] as? NSNumber)?.doubleValue
    }

    public func bool(_ key: String) -> Bool? {
        (raw[key] as? NSNumber)?.boolValue
    }

    public func array(_ key: String) -> [Any]? {
        raw[key] as? [Any]
    }

    public func objects(_ key: String) -> [JSONObject] {
        (raw[key] as? [[String: Any]])?.map(JSONObject.init) ?? []
    }

    public func date(_ key: String) -> Date? {
        guard let value = raw[key] as? String else { return nil }
        return ISO8601.date(from: value)
    }
}

/// ISO-8601 parsing that accepts timestamps both with and without fractional seconds.
///
/// Codex writes `2026-08-13T05:09:54.035Z`, Claude Code writes the same shape, but older
/// records in both tools omit the fractional part.
public enum ISO8601 {
    nonisolated(unsafe) private static let withFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    nonisolated(unsafe) private static let plain: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let lock = NSLock()

    public static func date(from string: String) -> Date? {
        lock.lock()
        defer { lock.unlock() }
        return withFraction.date(from: string) ?? plain.date(from: string)
    }
}
