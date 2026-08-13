import Foundation

/// An immutable view of every agent session at one instant.
///
/// The UI only ever renders a snapshot, which keeps rendering decoupled from the file
/// scanning that produces it and makes every display rule testable without touching disk.
public struct AgentSnapshot: Sendable, Equatable {
    public var sessions: [AgentSession]
    public var generatedAt: Date

    public init(sessions: [AgentSession] = [], generatedAt: Date = .distantPast) {
        self.sessions = sessions.sorted(by: AgentSnapshot.isMoreRelevant)
        self.generatedAt = generatedAt
    }

    public static let empty = AgentSnapshot()

    /// Sessions the agent is actively working in right now.
    public var workingSessions: [AgentSession] {
        sessions.filter { $0.activity == .working }
    }

    /// Sessions worth showing at all: still running, or finished recently enough to matter.
    public var liveSessions: [AgentSession] {
        sessions.filter { $0.activity != .idle }
    }

    /// The one session the collapsed island should represent.
    ///
    /// Working sessions win over waiting ones, and among equals the most recently active.
    public var headline: AgentSession? {
        sessions.first { $0.activity == .working } ?? sessions.first { $0.activity != .idle }
    }

    /// Combined consumption across every session in the snapshot.
    public var totalUsage: TokenUsage {
        sessions.reduce(TokenUsage()) { $0 + $1.usage }
    }

    /// The rate-limit window closest to being exhausted, across all providers.
    ///
    /// Rate limits are account-wide rather than per-session, so any session reporting one is
    /// speaking for the whole account; the most-consumed window is the one worth warning about.
    public var tightestRateLimit: RateLimitWindow? {
        sessions
            .flatMap { [$0.primaryRateLimit, $0.secondaryRateLimit] }
            .compactMap { $0 }
            .max { $0.usedPercent < $1.usedPercent }
    }

    public func sessions(for provider: AgentProvider) -> [AgentSession] {
        sessions.filter { $0.provider == provider }
    }

    /// Working first, then most recently active, then by identifier for a stable order.
    ///
    /// Stability matters: without a total ordering, equally-ranked rows swap places on every
    /// poll and the list visibly jitters.
    static func isMoreRelevant(_ lhs: AgentSession, _ rhs: AgentSession) -> Bool {
        if lhs.activity.isLive != rhs.activity.isLive {
            return lhs.activity.isLive
        }
        if lhs.lastActivityAt != rhs.lastActivityAt {
            return lhs.lastActivityAt > rhs.lastActivityAt
        }
        return lhs.id < rhs.id
    }
}
