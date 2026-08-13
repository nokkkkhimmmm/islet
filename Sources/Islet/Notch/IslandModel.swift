import AppKit
import Combine
import IsletCore

/// Observable state backing the island's views and window geometry.
///
/// Presentation is derived, never set directly: hovering wins, otherwise the island shows
/// itself only when there is agent activity worth showing. Keeping that rule in one place
/// stops the window controller and the views from disagreeing about what is on screen.
@MainActor
final class IslandModel: ObservableObject {
    @Published private(set) var presentation: IslandPresentation = .idle
    @Published private(set) var metrics: NotchMetrics

    /// Set by the hosting view as the pointer enters and leaves.
    @Published var isHovering: Bool = false

    let agents: AgentActivityMonitor

    private var cancellables: Set<AnyCancellable> = []

    init(agents: AgentActivityMonitor, metrics: NotchMetrics) {
        self.agents = agents
        self.metrics = metrics

        agents.$snapshot
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.recomputePresentation() }
            .store(in: &cancellables)

        $isHovering
            .removeDuplicates()
            .sink { [weak self] _ in self?.recomputePresentation() }
            .store(in: &cancellables)
    }

    var snapshot: AgentSnapshot { agents.snapshot }

    func updateMetrics(_ metrics: NotchMetrics) {
        guard metrics != self.metrics else { return }
        self.metrics = metrics
    }

    private func recomputePresentation() {
        let next: IslandPresentation
        if isHovering {
            next = .expanded
        } else if agents.snapshot.headline != nil {
            next = .active
        } else {
            next = .idle
        }

        guard next != presentation else { return }
        presentation = next
    }
}
