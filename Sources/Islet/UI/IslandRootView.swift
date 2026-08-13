import IsletCore
import SwiftUI

/// Root of the island. Chooses which presentation to draw and owns hover tracking.
///
/// The hosting window is always at least as tall as the notch plus a hover margin, so this
/// view lays everything out from the top edge down and lets the transparent remainder act
/// purely as a hit target.
struct IslandRootView: View {
    @EnvironmentObject private var model: IslandModel

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                // Covers the full window, including the invisible hover margin below the
                // notch, so the island opens slightly before the pointer reaches the cutout.
                Color.clear
                    .contentShape(Rectangle())

                island(width: proxy.size.width, height: proxy.size.height)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
        }
        .ignoresSafeArea()
        .onHover { hovering in
            model.isHovering = hovering
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: model.presentation)
    }

    @ViewBuilder
    private func island(width: CGFloat, height: CGFloat) -> some View {
        let notchHeight = model.metrics.notchHeight

        switch model.presentation {
        case .idle:
            // Exactly the cutout, so there is nothing for the eye to catch. Drawn rather
            // than omitted so the transition out of idle has something to grow from.
            NotchShape(bottomRadius: 0)
                .fill(Theme.surface)
                .frame(width: model.metrics.notchWidth, height: notchHeight)

        case .active:
            ActiveIslandView(notchWidth: model.metrics.notchWidth)
                .frame(width: width, height: notchHeight)
                .background(NotchShape(bottomRadius: Theme.collapsedRadius).fill(Theme.surface))

        case .expanded:
            ExpandedIslandView(notchHeight: notchHeight)
                .frame(width: width, height: height)
                .background(NotchShape(bottomRadius: Theme.expandedRadius).fill(Theme.surface))
        }
    }
}
