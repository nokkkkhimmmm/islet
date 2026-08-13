import IsletCore
import SwiftUI

/// The full panel: every recent agent session, what it is doing, and what it has spent.
struct ExpandedIslandView: View {
    @EnvironmentObject private var model: IslandModel

    /// Height of the cutout. Content starts below it, since those pixels do not exist.
    let notchHeight: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().overlay(Theme.divider)
            content
        }
        .padding(.top, notchHeight)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var sessions: [AgentSession] {
        Array(model.snapshot.liveSessions.prefix(4))
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("Agents")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.primaryText)

            if !model.snapshot.workingSessions.isEmpty {
                Text("\(model.snapshot.workingSessions.count) running")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.color(for: .working))
            }

            Spacer(minLength: 8)

            if let limit = model.snapshot.tightestRateLimit {
                RateLimitChip(window: limit)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var content: some View {
        if sessions.isEmpty {
            emptyState
        } else {
            VStack(spacing: 0) {
                ForEach(sessions) { session in
                    SessionRow(session: session)
                    if session.id != sessions.last?.id {
                        Divider().overlay(Theme.divider).padding(.leading, 16)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Text("No recent agent sessions")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.secondaryText)

            Text(installedHint)
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(Theme.tertiaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
    }

    private var installedHint: String {
        let installed = model.agents.installedProviders
        guard !installed.isEmpty else {
            return "Codex and Claude Code were not found in your home directory."
        }
        return "Watching \(installed.map(\.displayName).joined(separator: " and ")). Start a session to see it here."
    }
}

/// One session: where it is, what it is doing, and what it has cost.
struct SessionRow: View {
    let session: AgentSession

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ActivityDot(activity: session.activity, size: 8)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(session.workspaceName ?? "Untitled workspace")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.primaryText)
                        .lineLimit(1)

                    if let branch = session.gitBranch {
                        Text(branch)
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.tertiaryText)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white.opacity(0.08))
                            )
                            .lineLimit(1)
                    }
                }

                HStack(spacing: 6) {
                    Text(session.provider.displayName)
                    Text("·")
                    Text(Theme.label(for: session.activity))
                        .foregroundStyle(Theme.color(for: session.activity))
                    Text("·")
                    Text(Formatting.elapsed(since: session.lastActivityAt))
                }
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
                .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Text(Formatting.tokens(session.usage.total))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.primaryText)
                    .monospacedDigit()

                // Older transcripts omit the window size, so fall back to the raw occupancy
                // rather than showing a bar with no denominator behind it.
                if let fraction = session.contextFraction {
                    ContextBar(fraction: fraction)
                } else if let contextTokens = session.contextTokens {
                    Text("ctx \(Formatting.tokens(contextTokens))")
                        .font(.system(size: 9, design: .rounded))
                        .foregroundStyle(Theme.tertiaryText)
                        .monospacedDigit()
                } else {
                    Text("tokens")
                        .font(.system(size: 9, design: .rounded))
                        .foregroundStyle(Theme.tertiaryText)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

/// How full the model's context window is.
struct ContextBar: View {
    let fraction: Double

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.12))
                Capsule()
                    .fill(Theme.color(forUsage: fraction * 100))
                    .frame(width: max(2, 52 * fraction))
            }
            .frame(width: 52, height: 3)

            Text("ctx \(Formatting.percent(fraction * 100))")
                .font(.system(size: 9, design: .rounded))
                .foregroundStyle(Theme.tertiaryText)
                .monospacedDigit()
        }
    }
}

/// Account-level usage window, shown only when the provider reports one.
struct RateLimitChip: View {
    let window: RateLimitWindow

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Theme.color(forUsage: window.usedPercent))
                .frame(width: 5, height: 5)

            Text("\(Formatting.windowName(minutes: window.windowMinutes)) \(Formatting.percent(window.usedPercent))")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
                .monospacedDigit()

            if let resetsAt = window.resetsAt, let remaining = Formatting.remaining(until: resetsAt) {
                Text("· \(remaining)")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(Theme.tertiaryText)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            Capsule().fill(Color.white.opacity(0.07))
        )
        .lineLimit(1)
    }
}
