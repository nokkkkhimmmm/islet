import IsletCore
import SwiftUI

/// Visual constants for the island.
///
/// The island is always dark regardless of system appearance, because it is pretending to be
/// part of the physical notch — a light island would break the illusion immediately.
enum Theme {
    static let surface = Color.black
    static let primaryText = Color.white
    static let secondaryText = Color.white.opacity(0.55)
    static let tertiaryText = Color.white.opacity(0.35)
    static let divider = Color.white.opacity(0.10)

    static let collapsedRadius: CGFloat = 10
    static let expandedRadius: CGFloat = 22

    /// Status colours, chosen to stay legible against pure black.
    static func color(for activity: AgentActivity) -> Color {
        switch activity {
        case .working: return Color(red: 0.30, green: 0.85, blue: 0.45)
        case .awaitingInput: return Color(red: 1.00, green: 0.72, blue: 0.20)
        case .idle: return Color.white.opacity(0.30)
        }
    }

    static func label(for activity: AgentActivity) -> String {
        switch activity {
        case .working: return "Working"
        case .awaitingInput: return "Your turn"
        case .idle: return "Idle"
        }
    }

    /// Rate-limit bars go amber then red as a window fills.
    static func color(forUsage percent: Double) -> Color {
        switch percent {
        case ..<60: return Color(red: 0.30, green: 0.85, blue: 0.45)
        case ..<85: return Color(red: 1.00, green: 0.72, blue: 0.20)
        default: return Color(red: 1.00, green: 0.35, blue: 0.32)
        }
    }
}
