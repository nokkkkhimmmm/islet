import Foundation

/// Reads Claude Code session transcripts.
///
/// Claude Code writes one append-only JSONL file per session at
/// `~/.claude/projects/<slugified-workspace-path>/<session-uuid>.jsonl`. Each record is a
/// flat object carrying `type`, `timestamp`, `cwd`, `gitBranch`, `sessionId`, and — for
/// `assistant` and `user` records — a nested Anthropic-shaped `message`.
///
/// Two differences from Codex are worth knowing:
///
/// 1. There are no explicit turn-boundary records. Activity is instead read off the last
///    assistant message's `stop_reason`: `tool_use` means the agent is mid-turn waiting on a
///    tool, anything else means the turn ended. This is precise, not a timing heuristic.
/// 2. Usage is reported per message rather than cumulatively, so totals are summed here.
///    Input counts are per-request, which is what billing reflects, so the sum is a measure
///    of consumption and will legitimately exceed the context window on a long session.
///
/// As with Codex this is an undocumented on-disk format that changes between releases, so
/// unknown records are skipped rather than treated as errors.
public final class ClaudeCodeSessionSource: AgentSessionSource {
    public let provider: AgentProvider = .claudeCode
    public let rootDirectory: URL

    private let idleThreshold: TimeInterval
    private var cursors: [URL: TranscriptCursor] = [:]

    public init(
        rootDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects", isDirectory: true),
        idleThreshold: TimeInterval = 30 * 60
    ) {
        self.rootDirectory = rootDirectory
        self.idleThreshold = idleThreshold
    }

    public func scan(now: Date, lookback: TimeInterval) throws -> [AgentSession] {
        let cutoff = now.addingTimeInterval(-lookback)
        let urls = recentTranscripts(in: rootDirectory, modifiedAfter: cutoff)
        let live = Set(urls)
        cursors = cursors.filter { live.contains($0.key) }

        var sessions: [AgentSession] = []
        for url in urls {
            guard let session = try updateSession(at: url, now: now) else { continue }
            sessions.append(session)
        }
        return sessions
    }

    private func updateSession(at url: URL, now: Date) throws -> AgentSession? {
        var cursor = cursors[url] ?? TranscriptCursor()

        let modifiedAt = JSONLReader.modificationDate(of: url) ?? now
        if var cached = cursor.session, modifiedAt <= cursor.modifiedAt {
            cached.activity = decayedActivity(of: cached, now: now)
            cursor.session = cached
            cursors[url] = cursor
            return cached
        }

        let chunk = try JSONLReader.read(url: url, from: cursor.offset)
        cursor.offset = chunk.newOffset
        cursor.modifiedAt = modifiedAt

        var session = cursor.session ?? AgentSession(
            id: url.deletingPathExtension().lastPathComponent,
            provider: .claudeCode,
            startedAt: modifiedAt,
            lastActivityAt: modifiedAt
        )

        for record in chunk.objects {
            apply(record: record, to: &session)
        }

        session.activity = decayedActivity(of: session, now: now)
        cursor.session = session
        cursors[url] = cursor
        return session
    }

    private func apply(record: JSONObject, to session: inout AgentSession) {
        let type = record.string("type")
        guard type == "assistant" || type == "user" else {
            // Sidecar records (`ai-title`, `attachment`, `queue-operation`, …) carry no
            // usage or turn information.
            return
        }

        if let timestamp = record.date("timestamp") {
            if session.lastActivityAt == .distantPast { session.startedAt = timestamp }
            session.startedAt = min(session.startedAt, timestamp)
            session.lastActivityAt = max(session.lastActivityAt, timestamp)
        }
        if let sessionId = record.string("sessionId"), !sessionId.isEmpty {
            session.id = sessionId
        }
        if let cwd = record.string("cwd"), !cwd.isEmpty {
            session.workspacePath = cwd
        }
        // A detached checkout reports the literal string "HEAD", which is noise to show.
        if let branch = record.string("gitBranch"), !branch.isEmpty, branch != "HEAD" {
            session.gitBranch = branch
        }

        guard let message = record.object("message") else { return }

        if type == "user" {
            // The human (or a tool result) just spoke, so the agent is about to work.
            session.activity = .working
            return
        }

        if let model = message.string("model"), !model.isEmpty {
            session.model = model
        }
        if let usage = message.object("usage") {
            session.usage = session.usage + Self.usage(from: usage)
            session.contextTokens = Self.contextTokens(from: usage)
        }
        if let text = Self.assistantText(in: message) {
            session.lastMessagePreview = text
        }

        // `tool_use` means the agent stopped only to run a tool and will continue on its own.
        session.activity = message.string("stop_reason") == "tool_use" ? .working : .awaitingInput
    }

    private static func usage(from object: JSONObject) -> TokenUsage {
        TokenUsage(
            input: object.int("input_tokens") ?? 0,
            cachedInput: object.int("cache_read_input_tokens") ?? 0,
            cacheWrite: object.int("cache_creation_input_tokens") ?? 0,
            output: object.int("output_tokens") ?? 0
        )
    }

    /// Everything the model had to read for this request is what is sitting in its context.
    private static func contextTokens(from object: JSONObject) -> Int {
        (object.int("input_tokens") ?? 0)
            + (object.int("cache_read_input_tokens") ?? 0)
            + (object.int("cache_creation_input_tokens") ?? 0)
    }

    /// First visible text block of an assistant message, skipping `thinking` and `tool_use`.
    private static func assistantText(in message: JSONObject) -> String? {
        for block in message.objects("content") where block.string("type") == "text" {
            if let text = block.string("text"), let preview = previewText(text) {
                return preview
            }
        }
        return nil
    }

    private func decayedActivity(of session: AgentSession, now: Date) -> AgentActivity {
        guard now.timeIntervalSince(session.lastActivityAt) > idleThreshold else {
            return session.activity
        }
        return .idle
    }
}
