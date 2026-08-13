import CoreGraphics

/// How much of itself the island is currently showing.
enum IslandPresentation: Equatable {
    /// Exactly the notch. Nothing of Islet is visible.
    case idle
    /// Slightly wider than the notch, showing a live status readout in the strips beside it.
    case active
    /// Full panel hanging below the notch.
    case expanded

    var isExpanded: Bool { self == .expanded }
}

/// Fixed sizing rules for each presentation, resolved against a screen's real notch.
///
/// The island is always centred on the notch and always flush with the top of the screen, so a
/// state only needs to declare how far it reaches past the notch horizontally and vertically.
enum IslandLayout {
    /// How far `active` extends beyond each side of the notch, giving the status readout
    /// somewhere visible to live.
    static let activeSideInset: CGFloat = 96

    static let expandedWidth: CGFloat = 460
    static let expandedHeight: CGFloat = 300

    /// Invisible margin below the collapsed island, so the pointer registers a hover slightly
    /// before it reaches the cutout. Without it the island is fiddly to open.
    static let hoverPadding: CGFloat = 6

    static func size(for presentation: IslandPresentation, metrics: NotchMetrics) -> CGSize {
        switch presentation {
        case .idle:
            return CGSize(
                width: metrics.notchWidth,
                height: metrics.notchHeight + hoverPadding
            )
        case .active:
            return CGSize(
                width: metrics.notchWidth + activeSideInset * 2,
                height: metrics.notchHeight + hoverPadding
            )
        case .expanded:
            return CGSize(
                width: max(expandedWidth, metrics.notchWidth + activeSideInset * 2),
                height: expandedHeight
            )
        }
    }

    /// Window frame in screen coordinates, centred on the notch and pinned to the top edge.
    static func frame(for presentation: IslandPresentation, metrics: NotchMetrics) -> CGRect {
        let size = size(for: presentation, metrics: metrics)
        return CGRect(
            x: metrics.centerX - size.width / 2,
            y: metrics.topY - size.height,
            width: size.width,
            height: size.height
        )
    }
}
