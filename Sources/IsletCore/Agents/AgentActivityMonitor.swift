import Foundation

/// Owns the provider sources and produces snapshots.
///
/// Kept separate from `AgentActivityMonitor` so the mutable parsing state (byte cursors,
/// cached sessions) lives on exactly one serial queue while the observable state the UI reads
/// lives on the main thread. Neither reaches into the other.
///
/// `@unchecked Sendable` is a claim that every use is confined to `AgentActivityMonitor`'s
/// serial queue. Nothing else may hold a reference to one of these.
final class AgentScanner: @unchecked Sendable {
    private let sources: [AgentSessionSource]
    private let lookback: TimeInterval

    init(sources: [AgentSessionSource], lookback: TimeInterval) {
        self.sources = sources
        self.lookback = lookback
    }

    var installedProviders: [AgentProvider] {
        sources.filter(\.isInstalled).map(\.provider)
    }

    func scan(now: Date = Date()) -> AgentSnapshot {
        var sessions: [AgentSession] = []
        for source in sources where source.isInstalled {
            do {
                sessions += try source.scan(now: now, lookback: lookback)
            } catch {
                // A transcript being rotated or deleted mid-read is routine, not an error
                // worth surfacing; the next poll picks it up.
                continue
            }
        }
        return AgentSnapshot(sessions: sessions, generatedAt: now)
    }
}

/// Watches local agent transcripts and publishes a live `AgentSnapshot`.
///
/// Polls rather than using FSEvents. Both providers bury transcripts in dated directory trees
/// that FSEvents reports coarsely, and a poll that only stats files modified inside the
/// lookback window costs far less than the machinery to watch them — the expensive part,
/// parsing, is already incremental and skipped entirely when a file's mtime has not moved.
///
/// Scans run on a serial queue, so a slow scan cannot overlap the next tick by construction.
@MainActor
public final class AgentActivityMonitor: ObservableObject {
    /// Latest observed state. Replaced wholesale on each poll.
    @Published public private(set) var snapshot: AgentSnapshot = .empty

    /// Providers whose data directory actually exists on this machine.
    @Published public private(set) var installedProviders: [AgentProvider] = []

    private let scanner: AgentScanner
    private let interval: TimeInterval
    private let queue = DispatchQueue(label: "dev.islet.agent-scanner", qos: .utility)
    private var timer: DispatchSourceTimer?

    /// - Parameters:
    ///   - sources: Providers to watch. Defaults to Codex and Claude Code in their standard
    ///     home-directory locations.
    ///   - interval: Poll period. Two seconds reads as real time without measurable cost.
    ///   - lookback: How far back a transcript may have been modified and still be considered.
    public init(
        sources: [AgentSessionSource] = [CodexSessionSource(), ClaudeCodeSessionSource()],
        interval: TimeInterval = 2,
        lookback: TimeInterval = 12 * 60 * 60
    ) {
        self.scanner = AgentScanner(sources: sources, lookback: lookback)
        self.interval = interval
    }

    deinit {
        timer?.cancel()
    }

    public func start() {
        guard timer == nil else { return }

        let scanner = self.scanner
        let publish = makePublisher()

        queue.async { [weak self] in
            let providers = scanner.installedProviders
            Task { @MainActor [weak self] in
                self?.installedProviders = providers
            }
            publish(scanner.scan())
            _ = self
        }

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + interval, repeating: interval, leeway: .milliseconds(250))
        timer.setEventHandler {
            publish(scanner.scan())
        }
        timer.resume()
        self.timer = timer
    }

    public func stop() {
        timer?.cancel()
        timer = nil
    }

    /// Forces an immediate refresh, e.g. when the island is opened.
    public func refresh() {
        let scanner = self.scanner
        let publish = makePublisher()
        queue.async {
            publish(scanner.scan())
        }
    }

    /// A queue-safe sink that hands a finished snapshot back to the main actor.
    private func makePublisher() -> @Sendable (AgentSnapshot) -> Void {
        { [weak self] snapshot in
            Task { @MainActor [weak self] in
                guard let self, snapshot != self.snapshot else { return }
                self.snapshot = snapshot
            }
        }
    }
}
