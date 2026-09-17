import SwiftUI
import Core

struct ToolRowCard: View {
    var title: String
    var detail: String
    var isCode: Bool
    var availableWidth: CGFloat

    private static var maxWidth: CGFloat { HoverCardWidth.ceiling }
    private static let minWidth: CGFloat = 240

    var body: some View {
        MenuPanel {
            VStack(alignment: .leading, spacing: Metrics.spacingSmall) {
                Text(title)
                    .font(Typo.labelEmphasis)
                    .foregroundStyle(Palette.textPrimary)

                if !detail.isEmpty, detail != title {
                    Text(detail)
                        .font(isCode ? Typo.codeSmall : Typo.label)
                        .foregroundStyle(Palette.textSecondary)
                        .textSelection(.disabled)
                }
            }
            .frame(width: width, alignment: .leading)
            .padding(Metrics.inset)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var width: CGFloat {
        max(min(availableWidth - Metrics.gutter * 2, Self.maxWidth), Self.minWidth)
    }
}
