import SwiftUI

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
    static let bottomInset: CGFloat = 6

    static let coverHeight: CGFloat = 28
    static let textClearance: CGFloat = 12
}

extension EnvironmentValues {
    @Entry var composerRoom: ComposerRoom?
}
