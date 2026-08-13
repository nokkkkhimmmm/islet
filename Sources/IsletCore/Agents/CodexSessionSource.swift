import Foundation

/// Reads Codex CLI session transcripts.
///
/// Codex writes one append-only JSONL "rollout" file per session under
/// `~/.codex/sessions/<yyyy>/<MM>/<dd>/rollout-<timestamp>-<uuid>.jsonl`. Records are
/// `{"timestamp", "type", "payload"}` where `type` is one of `session_meta`, `event_msg`
/// or `response_item`, and the interesting details hang off `payload.type`:
///
/// - `session_meta`  — workspace path, git branch, CLI version, originator
/// - `token_count`   — cumulative and per-turn token usage, plus account rate limits
/// - `task_started`  / `task_complete` — explicit turn boundaries
/// - `agent_message` — the assistant's visible text
///
/// Codex is the better-behaved of the two providers because `task_started`/`task_complete`
/// give unambiguous turn boundaries, so activity is observed rather than guessed.
///
/// This format is not a documented public API and does change between Codex releases;
/// every field is read defensively and an unrecognised record is skipped, never fatal.
public final class CodexSessionSource: AgentSessionSource {
    public let provider: AgentProvider = .codex
    public let rootDirectory: URL

    /// A session with no new records for this long is considered over.
    private let idleThreshold: TimeInterval

    private var cursors: [URL: TranscriptCursor] = [:]

    public init(
        rootDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/sessions", isDirectory: true),
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
        // Nothing appended since we last looked: reuse the cached snapshot and only
        // re-evaluate whether it has now gone idle.
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
            provider: .codex,
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
        if let timestamp = record.date("timestamp") {
            session.lastActivityAt = max(session.lastActivityAt, timestamp)
        }

        guard let payload = record.object("payload") else { return }

        switch record.string("type") {
        case "session_meta":
            applySessionMeta(payload, to: &session)
        case "event_msg":
            applyEvent(payload, to: &session)
        default:
            // `response_item` records duplicate content we already read from `event_msg`.
            break
        }

        // The model is announced by whichever record type the current Codex release
        // happens to use (`thread_settings_applied`, `turn_context`, …), so take it
        // from any payload that carries one.
        if let model = payload.string("model"), !model.isEmpty {
            session.model = model
        }
    }

    private func applySessionMeta(_ payload: JSONObject, to session: inout AgentSession) {
        if let id = payload.string("session_id") ?? payload.string("id") {
            session.id = id
        }
        if let cwd = payload.string("cwd") {
            session.workspacePath = cwd
        }
        if let startedAt = payload.date("timestamp") {
            session.startedAt = startedAt
        }
        if let git = payload.object("git"), let branch = git.string("branch") {
            session.gitBranch = branch
        }
    }

    private func applyEvent(_ payload: JSONObject, to session: inout AgentSession) {
        switch payload.string("type") {
        case "task_started":
            session.activity = .working

        case "task_complete":
            session.activity = .awaitingInput

        case "token_count":
            if let info = payload.object("info") {
                if let total = info.object("total_token_usage") {
                    session.usage = Self.usage(from: total)
                }
                // The most recent turn's total is what is actually resident in the
                // context window; `total_token_usage` is cumulative consumption.
                if let last = info.object("last_token_usage") {
                    session.contextTokens = last.int("total_tokens")
                }
                // `model_context_window` is the real token capacity. Note that
                // `session_meta.context_window` is an unrelated identifier object.
                if let window = info.int("model_context_window"), window > 0 {
                    session.contextWindow = window
                }
            }
            if let limits = payload.object("rate_limits") {
                session.primaryRateLimit = Self.rateLimit(from: limits.object("primary"))
                session.secondaryRateLimit = Self.rateLimit(from: limits.object("secondary"))
                session.planType = limits.string("plan_type")
            }

        case "agent_message":
            if let message = payload.string("message") {
                session.lastMessagePreview = previewText(message)
            }

        default:
            break
        }
    }

    private static func usage(from object: JSONObject) -> TokenUsage {
        TokenUsage(
            input: object.int("input_tokens") ?? 0,
            cachedInput: object.int("cached_input_tokens") ?? 0,
            cacheWrite: object.int("cache_write_input_tokens") ?? 0,
            output: object.int("output_tokens") ?? 0,
            reasoning: object.int("reasoning_output_tokens") ?? 0,
            reportedTotal: object.int("total_tokens")
        )
    }

    /// Codex has used both an absolute `resets_at` epoch and a relative `resets_in_seconds`
    /// across releases, so accept either.
    private static func rateLimit(from object: JSONObject?) -> RateLimitWindow? {
        guard let object, let usedPercent = object.double("used_percent") else { return nil }

        var resetsAt: Date?
        if let epoch = object.double("resets_at") {
            resetsAt = Date(timeIntervalSince1970: epoch)
        } else if let seconds = object.double("resets_in_seconds") {
            resetsAt = Date().addingTimeInterval(seconds)
        }

        return RateLimitWindow(
            usedPercent: usedPercent,
            windowMinutes: object.int("window_minutes"),
            resetsAt: resetsAt
        )
    }

    /// A transcript that stops mid-turn (the process was killed, the machine slept) would
    /// otherwise stay `working` forever, so age it out.
    private func decayedActivity(of session: AgentSession, now: Date) -> AgentActivity {
        guard now.timeIntervalSince(session.lastActivityAt) > idleThreshold else {
            return session.activity
        }
        return .idle
    }
}
