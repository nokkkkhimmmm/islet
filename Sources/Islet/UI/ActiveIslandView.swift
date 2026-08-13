import IsletCore
import SwiftUI

/// The glanceable state: a status readout in the two strips either side of the cutout.
///
/// Nothing may be drawn in the middle `notchWidth` — there is no display behind it — so the
/// layout reserves that span as empty and pushes content outward.
struct ActiveIslandView: View {
    @EnvironmentObject private var model: IslandModel
    let notchWidth: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            leading
                .frame(width: IslandLayout.activeSideInset, alignment: .trailing)
                .padding(.trailing, 8)

            // The cutout itself.
            Color.clear.frame(width: notchWidth)

            trailing
                .frame(width: IslandLayout.activeSideInset, alignment: .leading)
                .padding(.leading, 8)
        }
    }

    private var session: AgentSession? { model.snapshot.headline }

    @ViewBuilder
    private var leading: some View {
        if let session {
            HStack(spacing: 6) {
                ActivityDot(activity: session.activity)

                Text(session.workspaceName ?? session.provider.displayName)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
    }

    @ViewBuilder
    private var trailing: some View {
        if let session {
            HStack(spacing: 6) {
                Text(Formatting.tokens(session.usage.total))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.primaryText)
                    .monospacedDigit()

                Text(session.provider.shortName)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.tertiaryText)
            }
            .lineLimit(1)
        }
    }
}

/// Status indicator that breathes only while the agent is actually working, so a glance at
/// the notch answers "is it still going?" without reading anything.
struct ActivityDot: View {
    let activity: AgentActivity
    var size: CGFloat = 7

    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(Theme.color(for: activity))
            .frame(width: size, height: size)
            .opacity(isPulsing ? 0.35 : 1)
            .animation(
                activity.isLive
                    ? .easeInOut(duration: 0.75).repeatForever(autoreverses: true)
                    : .default,
                value: isPulsing
            )
            .onAppear { isPulsing = activity.isLive }
            .onChange(of: activity) { _, newValue in
                isPulsing = newValue.isLive
            }
    }
}
