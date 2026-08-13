import AppKit

/// Borderless panel that floats above the menu bar and never takes focus.
///
/// A non-activating panel is essential: clicking the island must not pull the user out of
/// whatever they are working in, which is the whole point of a glanceable surface.
final class NotchWindow: NSPanel {
    init(contentRect: CGRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        isMovableByWindowBackground = false
        ignoresMouseEvents = false
        hidesOnDeactivate = false

        // One above the status bar puts the island over the menu bar, which is where the
        // notch physically is. Anything lower is drawn underneath it and never seen.
        level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)

        collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .fullScreenAuxiliary,
            .ignoresCycle,
        ]
    }

    // Borderless panels refuse key status by default, which would stop text fields and
    // buttons inside the island from ever responding.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
