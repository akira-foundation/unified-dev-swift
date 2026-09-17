import SwiftUI
import Core

struct InstructionsCard: View {
    var text: String
    var availableWidth: CGFloat

    private static var maxWidth: CGFloat { HoverCardWidth.ceiling }
    private static let minWidth: CGFloat = 240

    var body: some View {
        MenuPanel {
            VStack(alignment: .leading, spacing: 0) {
                if let head = TextHead.head(of: text) {
                    SourceLines(lines: head.lines, truncated: head.truncated)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Metrics.inset)
                }

                Text("In the message itself")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Metrics.inset)
                    .padding(.vertical, Metrics.spacing)
            }
            .frame(width: width, alignment: .leading)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var width: CGFloat {
        max(min(availableWidth - Metrics.gutter * 2, Self.maxWidth), Self.minWidth)
    }
}
