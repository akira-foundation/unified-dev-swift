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
        .anchorPreference(key: ComposerDockBounds.self, value: .bounds) { [$0] }
    }
}

struct ComposerDockBounds: PreferenceKey {
    static let defaultValue: [Anchor<CGRect>] = []

    static func reduce(value: inout [Anchor<CGRect>], nextValue: () -> [Anchor<CGRect>]) {
        value.append(contentsOf: nextValue())
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
