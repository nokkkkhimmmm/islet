import AppKit
import Combine
import SwiftUI

/// Owns the notch panel and keeps its frame in step with the island's presentation.
///
/// The window is resized rather than kept at maximum size, so when the island is idle it
/// occupies only the notch and leaves the rest of the menu bar clickable.
@MainActor
final class NotchWindowController {
    private let model: IslandModel
    private var window: NotchWindow?
    private var cancellables: Set<AnyCancellable> = []

    init(model: IslandModel) {
        self.model = model
    }

    func show() {
        guard window == nil else { return }
        guard let screen = NotchGeometry.islandScreen() else { return }

        let metrics = NotchGeometry.metrics(for: screen)
        model.updateMetrics(metrics)

        let frame = IslandLayout.frame(for: model.presentation, metrics: metrics)
        let window = NotchWindow(contentRect: frame)

        let hosting = NSHostingView(rootView: IslandRootView().environmentObject(model))
        hosting.frame = CGRect(origin: .zero, size: frame.size)
        hosting.autoresizingMask = [.width, .height]
        window.contentView = hosting

        window.setFrame(frame, display: true)
        window.orderFrontRegardless()
        self.window = window

        model.$presentation
            .removeDuplicates()
            .sink { [weak self] presentation in
                self?.applyFrame(for: presentation, animated: true)
            }
            .store(in: &cancellables)

        // Docking or undocking a display, or changing resolution, moves the notch.
        NotificationCenter.default
            .publisher(for: NSApplication.didChangeScreenParametersNotification)
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.screenParametersChanged() }
            .store(in: &cancellables)
    }

    func hide() {
        window?.orderOut(nil)
        window = nil
        cancellables.removeAll()
    }

    private func screenParametersChanged() {
        guard let screen = NotchGeometry.islandScreen() else { return }
        model.updateMetrics(NotchGeometry.metrics(for: screen))
        applyFrame(for: model.presentation, animated: false)
    }

    private func applyFrame(for presentation: IslandPresentation, animated: Bool) {
        guard let window else { return }
        let frame = IslandLayout.frame(for: presentation, metrics: model.metrics)

        guard animated else {
            window.setFrame(frame, display: true)
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.28
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            context.allowsImplicitAnimation = true
            window.animator().setFrame(frame, display: true)
        }
    }
}
