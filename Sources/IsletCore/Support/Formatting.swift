import Foundation

/// Compact formatters for the island, where a value has to read at a glance in very little space.
public enum Formatting {
    /// Token counts as `812`, `45.3k`, `1.2M`.
    public static func tokens(_ count: Int) -> String {
        let magnitude = abs(count)
        switch magnitude {
        case 0..<1_000:
            return "\(count)"
        case 1_000..<1_000_000:
            return trimmed(Double(count) / 1_000) + "k"
        default:
            return trimmed(Double(count) / 1_000_000) + "M"
        }
    }

    /// Elapsed time as `now`, `12s`, `4m`, `2h`, `3d`.
    public static func elapsed(since date: Date, now: Date = Date()) -> String {
        let seconds = max(0, now.timeIntervalSince(date))
        switch seconds {
        case 0..<3: return "now"
        case 3..<60: return "\(Int(seconds))s"
        case 60..<3_600: return "\(Int(seconds / 60))m"
        case 3_600..<86_400: return "\(Int(seconds / 3_600))h"
        default: return "\(Int(seconds / 86_400))d"
        }
    }

    /// Time remaining as `4m left`, `2h left`, `3d left`, or nil once it has passed.
    public static func remaining(until date: Date, now: Date = Date()) -> String? {
        let seconds = date.timeIntervalSince(now)
        guard seconds > 0 else { return nil }
        switch seconds {
        case 0..<3_600: return "\(max(1, Int(seconds / 60)))m left"
        case 3_600..<86_400: return "\(Int(seconds / 3_600))h left"
        default: return "\(Int(seconds / 86_400))d left"
        }
    }

    /// A percentage with no decimal noise: `10%`, `87%`.
    public static func percent(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }

    /// Names a rate-limit window by its duration, since providers report minutes rather
    /// than a label: 300 minutes is the five-hour window, 10080 the weekly one.
    public static func windowName(minutes: Int?) -> String {
        guard let minutes, minutes > 0 else { return "Usage" }
        switch minutes {
        case ..<60:
            return "\(minutes)m limit"
        case ..<1_440:
            return "\(minutes / 60)h limit"
        case 10_080:
            return "Weekly limit"
        default:
            return "\(minutes / 1_440)d limit"
        }
    }

    /// One decimal place, but only when it says something: `1.2k`, not `45.0k`.
    private static func trimmed(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if rounded == rounded.rounded() {
            return String(Int(rounded))
        }
        return String(format: "%.1f", rounded)
    }
}
