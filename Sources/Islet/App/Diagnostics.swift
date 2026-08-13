import AppKit

/// Prints what Islet worked out about this Mac's displays and where it intends to draw.
///
/// Notch geometry varies by model, and Islet cannot be tested on every one. When someone
/// reports the island sitting in the wrong place, this output identifies the cause without
/// needing a screenshot or a debugger.
enum Diagnostics {
    static func describeDisplays() -> String {
        var lines: [String] = []
        let chosen = NotchGeometry.islandScreen()

        lines.append("Screens (\(NSScreen.screens.count)):")
        for screen in NSScreen.screens {
            let isChosen = screen == chosen
            let name = screen.localizedName
            let frame = screen.frame
            let hasNotch = screen.auxiliaryTopLeftArea != nil

            lines.append("  \(isChosen ? "▸" : " ") \(name)")
            lines.append("      frame: \(short(frame))  backingScale: \(screen.backingScaleFactor)")
            lines.append("      notch: \(hasNotch ? "yes" : "no")  safeAreaInset.top: \(screen.safeAreaInsets.top)")
            if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
                lines.append("      auxLeft: \(short(left))  auxRight: \(short(right))")
            }
        }

        guard let chosen else {
            lines.append("\nNo usable screen found — the island will not be shown.")
            return lines.joined(separator: "\n")
        }

        let metrics = NotchGeometry.metrics(for: chosen)
        lines.append("")
        lines.append("Island target: \(chosen.localizedName)")
        lines.append("  physical notch: \(metrics.hasPhysicalNotch ? "yes" : "no (using a synthetic pill below the menu bar)")")
        lines.append("  notch frame: \(short(metrics.notchFrame))")
        lines.append("")
        lines.append("Window frames:")
        for presentation in [IslandPresentation.idle, .active, .expanded] {
            let frame = IslandLayout.frame(for: presentation, metrics: metrics)
            lines.append("  \(String(describing: presentation).padding(toLength: 9, withPad: " ", startingAt: 0)) \(short(frame))")
        }

        return lines.joined(separator: "\n")
    }

    private static func short(_ rect: CGRect) -> String {
        let format: (CGFloat) -> String = { String(format: "%.1f", $0) }
        return "(\(format(rect.origin.x)), \(format(rect.origin.y))) \(format(rect.width))×\(format(rect.height))"
    }
}
