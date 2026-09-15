import SwiftUI

/// A floating writing surface. Its clearance belongs to the transcript document, so the
/// newest message clears the glass without shortening the viewport while reading history.
struct ComposerDock<Content: View>: View {
    var showsJumpToNewest: Bool
    var onJumpToNewest: @MainActor @Sendable () -> Void
    @ViewBuilder var content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GlassEffectContainer(spacing: Metrics.spacingSmall) {
            VStack(spacing: Metrics.spacingWide) {
                if showsJumpToNewest {
                    JumpToNewestPill(action: onJumpToNewest)
                        .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 4)))
                }

                content
            }
        }
        .animation(reduceMotion ? nil : Motion.pane, value: showsJumpToNewest)
    }
}

enum ComposerLayout {
    static let horizontalInset: CGFloat = 16
    /// Six, not fourteen. This is the strip of pane left under the writing surface, and all it
    /// has to do is keep the box off the window's edge: at fourteen it read as a band of its own
    /// along the foot of the column.
    static let bottomInset: CGFloat = 6

    /// How much of the pane the strip under the box covers. More than `bottomInset`, because what
    /// has to be hidden is not only the gap: a line of the transcript passing a few points above
    /// the box's bottom edge shows through the rounded corners as well.
    static let coverHeight: CGFloat = 28
    static let textClearance: CGFloat = 12
}

extension EnvironmentValues {
    /// Absent on archived transcripts and other read-only presentations.
    @Entry var composerRoom: ComposerRoom?
}
