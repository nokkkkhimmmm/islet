import Foundation

/// One-shot, non-UI access to the same data the island shows.
///
/// Exposed so `islet --dump-sessions` can print exactly what the parsers see. Being able to
/// diff that against a transcript is the fastest way to tell a parsing bug apart from a
/// rendering one, and it gives contributors a way to report format drift without a debugger.
public enum AgentDiagnostics {
    public static func snapshot(
        sources: [AgentSessionSource] = [CodexSessionSource(), ClaudeCodeSessionSource()],
        lookback: TimeInterval = 12 * 60 * 60,
        now: Date = Date()
    ) -> AgentSnapshot {
        AgentScanner(sources: sources, lookback: lookback).scan(now: now)
    }

    public static func describe(_ snapshot: AgentSnapshot, now: Date = Date()) -> String {
        var lines: [String] = []
        lines.append("Islet — \(snapshot.sessions.count) session(s) in the lookback window")

        if let limit = snapshot.tightestRateLimit {
            var text = "  \(Formatting.windowName(minutes: limit.windowMinutes)): \(Formatting.percent(limit.usedPercent)) used"
            if let resetsAt = limit.resetsAt, let remaining = Formatting.remaining(until: resetsAt, now: now) {
                text += " (\(remaining))"
            }
            lines.append(text)
        }

        guard !snapshot.sessions.isEmpty else {
            lines.append("  (nothing found — is Codex or Claude Code installed for this user?)")
            return lines.joined(separator: "\n")
        }

        lines.append("")
        for session in snapshot.sessions {
            lines.append("  [\(session.activity.rawValue)] \(session.provider.displayName) — \(session.workspaceName ?? "unknown workspace")")

            var detail = "      model: \(session.model ?? "?")"
            if let branch = session.gitBranch { detail += "  branch: \(branch)" }
            detail += "  last activity: \(Formatting.elapsed(since: session.lastActivityAt, now: now))"
            lines.append(detail)

            var usage = "      tokens: \(Formatting.tokens(session.usage.total)) total"
            usage += " (in \(Formatting.tokens(session.usage.input))"
            usage += ", cached \(Formatting.tokens(session.usage.cachedInput))"
            usage += ", out \(Formatting.tokens(session.usage.output)))"
            lines.append(usage)

            if let contextTokens = session.contextTokens {
                var context = "      context: \(Formatting.tokens(contextTokens))"
                if let window = session.contextWindow {
                    context += " / \(Formatting.tokens(window))"
                }
                if let fraction = session.contextFraction {
                    context += "  (\(Formatting.percent(fraction * 100)))"
                }
                lines.append(context)
            }

            if let preview = session.lastMessagePreview {
                lines.append("      last: \(preview)")
            }
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }
}
