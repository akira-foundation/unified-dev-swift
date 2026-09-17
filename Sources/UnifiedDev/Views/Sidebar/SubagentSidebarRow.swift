import SwiftUI
import Core

struct SubagentSidebarRow: View {
    var row: SubagentRow

    @Environment(\.backgroundProminence) private var prominence

    private var isOnSelection: Bool { prominence == .increased }

    var body: some View {
        Label {
            HStack(spacing: Metrics.spacingSmall) {
                Text(row.title)
                    .font(Typo.caption)
                    .foregroundStyle(isOnSelection ? Palette.textInverted : Palette.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: Metrics.spacingSmall)

                if !row.detail.text.isEmpty {
                    Text(row.detail.text)
                        .font(Typo.micro)
                        .monospacedDigit()
                        .foregroundStyle(
                            isOnSelection ? Palette.textInverted.opacity(0.8) : Palette.textTertiary
                        )
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .layoutPriority(-1)
                }
            }
        } icon: {
            SubagentMarkGlyph(mark: row.mark, isOnSelection: isOnSelection)
        }
        .labelStyle(SidebarRowLabelStyle())
        .padding(.leading, SidebarMetrics.rowIndent + SidebarMetrics.subagentIndent)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(row.title))
        .accessibilityValue(Text(row.spokenValue))
        .accessibilityCustomContent(Text("Subagent"), Text(row.title), importance: .high)
        .help(row.spokenValue)
    }
}

struct SubagentMarkGlyph: View {
    var mark: SubagentRow.Mark
    var isOnSelection = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        content
            .frame(width: Metrics.glyph, height: Metrics.glyph)
    }

    @ViewBuilder
    private var content: some View {
        switch mark {
        case .working:
            BreathingMark(isMoving: !reduceMotion) { symbol }
        default:
            symbol
        }
    }

    private var symbol: some View {
        Image(systemName: Self.symbol(for: mark))
            .font(Typo.micro)
            .imageScale(.medium)
            .foregroundStyle(isOnSelection ? Palette.textInverted : Self.tint(for: mark))
            .accessibilityLabel(mark.word)
    }

    static func symbol(for mark: SubagentRow.Mark) -> String {
        switch mark {
        case .working: "ellipsis"
        case .done: "checkmark"
        case .failed: "xmark"
        case .stopped: "minus"
        }
    }

    static func tint(for mark: SubagentRow.Mark) -> Color {
        switch mark {
        case .done: Palette.positive
        case .failed: Palette.negative
        case .working: Palette.running
        case .stopped: Palette.textTertiary
        }
    }
}
