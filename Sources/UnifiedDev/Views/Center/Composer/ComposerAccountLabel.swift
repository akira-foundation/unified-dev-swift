import SwiftUI
import Core

struct ComposerAccountLabel: View {
    var line: AgentAccountLine
    var isCompact: Bool

    @State private var isExplaining = false

    var body: some View {
        if line.warns || (!isCompact && line.title != nil) {
            Button {
                isExplaining = true
            } label: {
                HStack(spacing: Metrics.spacingSmall) {
                    if line.warns {
                        Image(systemName: "exclamationmark.triangle.fill")
                    }
                    if !isCompact, let title = line.title {
                        Text(title)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .font(Typo.label)
                .foregroundStyle(line.warns ? Palette.warning : Palette.textSecondary)
                .padding(.horizontal, Metrics.spacing)
                .padding(.vertical, Metrics.spacingSmall)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(line.sentence)
            .popover(isPresented: $isExplaining, arrowEdge: .top) {
                Text(line.sentence)
                    .font(Typo.caption)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: 260, alignment: .leading)
                    .padding(Metrics.gutter)
                    .environment(\.fontScale, 1)
            }
            .accessibilityLabel("Account")
            .accessibilityValue(line.sentence)
        }
    }
}
