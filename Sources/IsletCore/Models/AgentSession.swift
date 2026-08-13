import Foundation

/// A coding agent whose local session transcripts Islet can read.
public enum AgentProvider: String, Sendable, Codable, CaseIterable, Identifiable {
    case codex
    case claudeCode

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .codex: return "Codex"
        case .claudeCode: return "Claude Code"
        }
    }

    /// Short label for the collapsed island, where horizontal space is scarce.
    public var shortName: String {
        switch self {
        case .codex: return "CDX"
        case .claudeCode: return "CC"
        }
    }
}

/// What the agent appears to be doing right now.
///
/// Derived from transcript records, so it is an observation rather than a subscription to
/// agent state — see the per-provider notes in `CodexSessionSource` and `ClaudeCodeSessionSource`
/// for exactly how each is inferred and how reliable it is.
public enum AgentActivity: String, Sendable, Codable {
    /// The agent is mid-turn: thinking, calling tools, or writing a response.
    case working
    /// The turn finished and the agent is waiting for the human.
    case awaitingInput
    /// No transcript activity for a while; the session is probably over.
    case idle

    public var isLive: Bool { self == .working }
}

/// Token counts for a single session.
///
/// Field names mirror the union of what the two providers report; a provider that does not
/// break out a given number leaves it at zero rather than guessing.
public struct TokenUsage: Sendable, Codable, Equatable {
    public var input: Int = 0
    public var cachedInput: Int = 0
    public var cacheWrite: Int = 0
    public var output: Int = 0
    public var reasoning: Int = 0

    /// Provider-reported total when available, otherwise the sum of the parts.
    public var reportedTotal: Int?

    public init(
        input: Int = 0,
        cachedInput: Int = 0,
        cacheWrite: Int = 0,
        output: Int = 0,
        reasoning: Int = 0,
        reportedTotal: Int? = nil
    ) {
        self.input = input
        self.cachedInput = cachedInput
        self.cacheWrite = cacheWrite
        self.output = output
        self.reasoning = reasoning
        self.reportedTotal = reportedTotal
    }

    public var total: Int {
        reportedTotal ?? (input + cachedInput + cacheWrite + output + reasoning)
    }

    /// Tokens that were actually billed as fresh input, i.e. excluding cache reads.
    public var billableInput: Int { input + cacheWrite }

    public static func + (lhs: TokenUsage, rhs: TokenUsage) -> TokenUsage {
        TokenUsage(
            input: lhs.input + rhs.input,
            cachedInput: lhs.cachedInput + rhs.cachedInput,
            cacheWrite: lhs.cacheWrite + rhs.cacheWrite,
            output: lhs.output + rhs.output,
            reasoning: lhs.reasoning + rhs.reasoning,
            reportedTotal: {
                switch (lhs.reportedTotal, rhs.reportedTotal) {
                case let (l?, r?): return l + r
                case let (l?, nil): return l
                case let (nil, r?): return r
                case (nil, nil): return nil
                }
            }()
        )
    }
}

/// A usage window reported by the provider, such as a rolling five-hour quota.
public struct RateLimitWindow: Sendable, Codable, Equatable {
    public var usedPercent: Double
    public var windowMinutes: Int?
    public var resetsAt: Date?

    public init(usedPercent: Double, windowMinutes: Int? = nil, resetsAt: Date? = nil) {
        self.usedPercent = usedPercent
        self.windowMinutes = windowMinutes
        self.resetsAt = resetsAt
    }

    public var isNearingLimit: Bool { usedPercent >= 80 }
}

/// A single agent session observed on disk.
public struct AgentSession: Sendable, Codable, Equatable, Identifiable {
    public var id: String
    public var provider: AgentProvider

    /// Absolute path of the workspace the agent is operating in, when the transcript records it.
    public var workspacePath: String?
    public var gitBranch: String?
    public var model: String?

    public var activity: AgentActivity

    /// Everything the session has consumed since it started. Grows monotonically and will
    /// exceed the context window on any long session — this is consumption, not occupancy.
    public var usage: TokenUsage

    /// Tokens currently resident in the model's context window, i.e. occupancy.
    public var contextTokens: Int?

    /// Capacity of the context window, only set when the provider actually reports it.
    /// Islet never guesses this from the model name.
    public var contextWindow: Int?

    public var startedAt: Date
    public var lastActivityAt: Date

    public var primaryRateLimit: RateLimitWindow?
    public var secondaryRateLimit: RateLimitWindow?

    /// Subscription tier the provider reported, e.g. `plus`. Purely informational.
    public var planType: String?

    /// Short human-readable hint about the most recent turn, for the expanded island.
    public var lastMessagePreview: String?

    public init(
        id: String,
        provider: AgentProvider,
        workspacePath: String? = nil,
        gitBranch: String? = nil,
        model: String? = nil,
        activity: AgentActivity = .idle,
        usage: TokenUsage = TokenUsage(),
        contextTokens: Int? = nil,
        contextWindow: Int? = nil,
        startedAt: Date,
        lastActivityAt: Date,
        primaryRateLimit: RateLimitWindow? = nil,
        secondaryRateLimit: RateLimitWindow? = nil,
        planType: String? = nil,
        lastMessagePreview: String? = nil
    ) {
        self.id = id
        self.provider = provider
        self.workspacePath = workspacePath
        self.gitBranch = gitBranch
        self.model = model
        self.activity = activity
        self.usage = usage
        self.contextTokens = contextTokens
        self.contextWindow = contextWindow
        self.startedAt = startedAt
        self.lastActivityAt = lastActivityAt
        self.primaryRateLimit = primaryRateLimit
        self.secondaryRateLimit = secondaryRateLimit
        self.planType = planType
        self.lastMessagePreview = lastMessagePreview
    }

    /// Last path component of the workspace — what a person actually calls the project.
    public var workspaceName: String? {
        guard let workspacePath, !workspacePath.isEmpty else { return nil }
        let name = (workspacePath as NSString).lastPathComponent
        return name.isEmpty ? nil : name
    }

    /// How full the model's context window is, if the provider reported both a window size
    /// and current occupancy.
    public var contextFraction: Double? {
        guard let contextWindow, contextWindow > 0, let contextTokens else { return nil }
        return min(Double(contextTokens) / Double(contextWindow), 1)
    }
}
