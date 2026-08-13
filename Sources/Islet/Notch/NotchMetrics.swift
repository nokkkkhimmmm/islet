import AppKit

/// Physical description of a screen's notch, or a sensible stand-in when there isn't one.
struct NotchMetrics: Equatable {
    /// Rect of the camera housing in screen coordinates (origin bottom-left).
    ///
    /// On a notched Mac this area is a physical cutout: there are no pixels behind it. Anything
    /// Islet draws has to live in the strips to the left and right of this rect, or below it.
    var notchFrame: CGRect

    /// Full frame of the screen the island belongs to.
    var screenFrame: CGRect

    /// False when synthesised for a Mac without a notch.
    var hasPhysicalNotch: Bool

    var notchWidth: CGFloat { notchFrame.width }
    var notchHeight: CGFloat { notchFrame.height }

    /// Horizontal centre of the notch, which every island state is centred on.
    var centerX: CGFloat { notchFrame.midX }

    /// Y coordinate of the screen's top edge.
    var topY: CGFloat { screenFrame.maxY }
}

enum NotchGeometry {
    /// Islet lives on the built-in display, since that is the only one with a notch.
    ///
    /// `NSScreen.screens.first` is the screen containing the origin, which is not necessarily
    /// built-in, so prefer an actual notched screen and fall back to the main one.
    static func islandScreen() -> NSScreen? {
        NSScreen.screens.first(where: { $0.auxiliaryTopLeftArea != nil }) ?? NSScreen.main
    }

    static func metrics(for screen: NSScreen) -> NotchMetrics {
        let frame = screen.frame

        // A notched screen exposes the usable regions either side of the camera housing.
        // Whatever is left over between them is the notch itself.
        if let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            let width = frame.width - left.width - right.width
            let height = screen.safeAreaInsets.top

            if width > 0, height > 0 {
                return NotchMetrics(
                    notchFrame: CGRect(
                        x: frame.minX + (frame.width - width) / 2,
                        y: frame.maxY - height,
                        width: width,
                        height: height
                    ),
                    screenFrame: frame,
                    hasPhysicalNotch: true
                )
            }
        }

        return syntheticMetrics(for: screen)
    }

    /// Stand-in island for Macs without a notch: a pill tucked just under the menu bar.
    ///
    /// It deliberately sits *below* the menu bar rather than over it, because on these Macs
    /// that space holds real menu items instead of a cutout.
    private static func syntheticMetrics(for screen: NSScreen) -> NotchMetrics {
        let frame = screen.frame
        let width: CGFloat = 180
        let height: CGFloat = 32
        let menuBarHeight = max(frame.maxY - screen.visibleFrame.maxY, NSStatusBar.system.thickness)

        return NotchMetrics(
            notchFrame: CGRect(
                x: frame.minX + (frame.width - width) / 2,
                y: frame.maxY - menuBarHeight - height,
                width: width,
                height: height
            ),
            screenFrame: frame,
            hasPhysicalNotch: false
        )
    }
}
