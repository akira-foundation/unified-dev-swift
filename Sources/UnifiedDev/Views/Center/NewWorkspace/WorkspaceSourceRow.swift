import SwiftUI
import Core

struct WorkspaceSourceRow: View {
    var source: WorkspaceSource
    var isSelected: Bool
    var onPick: @MainActor () -> Void
    var onHover: @MainActor () -> Void

    @Environment(\.controlActiveState) private var activeState

    @State private var isHovered = false

    var body: some View {
        Button(action: onPick) {
            HStack(spacing: Metrics.spacing) {
                Image(systemName: glyph)
                    .imageScale(.small)
                    .foregroundStyle(isEmphasized ? Palette.selectedEmphasizedText : Palette.textTertiary)
                    .frame(width: Metrics.glyph)

                VStack(alignment: .leading, spacing: Metrics.spacingTight) {
                    Text(source.name)
                        .font(Typo.body)
                        .foregroundStyle(nameColour)
                        .lineLimit(1)
                        .truncationMode(truncation)

                    if let detail = source.detail {
                        Text(detail)
                            .font(Typo.caption)
                            .foregroundStyle(
                                isEmphasized
                                    ? Palette.selectedEmphasizedText.opacity(0.75)
                                    : Palette.textTertiary
                            )
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }

                Spacer(minLength: Metrics.spacingSmall)

                if let note = source.note {
                    Text(note)
                        .font(Typo.caption)
                        .foregroundStyle(
                            isEmphasized
                                ? Palette.selectedEmphasizedText.opacity(0.75)
                                : Palette.textTertiary
                        )
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, Metrics.spacing)
            .padding(.vertical, Metrics.spacingTight)
            .frame(minHeight: Metrics.rowHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(source.verb) \(source.name)")
        .accessibilityValue([source.detail, source.note].compactMap { $0 }.joined(separator: ", "))
        .rowBackground(isSelected: isSelected, isHovered: isHovered, isFocused: true)
        .onHover { hovering in
            isHovered = hovering
            if hovering { onHover() }
        }
    }

    private var truncation: Text.TruncationMode {
        source.name.hasPrefix("#") ? .tail : .head
    }

    private var glyph: String {
        switch source {
        case .pullRequest: "arrow.triangle.pull"
        case .existingBranch: "arrow.triangle.branch"
        case .newBranch: "plus.circle"
        }
    }

    private var nameColour: Color {
        if isEmphasized { return Palette.selectedEmphasizedText }
        return source.heldBy == nil ? Palette.textPrimary : Palette.textTertiary
    }

    private var isEmphasized: Bool {
        isSelected && activeState != .inactive
    }
}
