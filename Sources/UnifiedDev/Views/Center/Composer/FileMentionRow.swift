import SwiftUI
import Core

struct FileMentionRow: View {
    var match: FileMatch
    var isSelected: Bool
    var onPick: @MainActor () -> Void
    var onHover: @MainActor () -> Void

    @Environment(\.controlActiveState) private var activeState

    @State private var isHovered = false

    var body: some View {
        Button(action: onPick) {
            HStack(spacing: Metrics.spacing) {
                Text(match.fileName)
                    .font(Typo.body)
                    .foregroundStyle(isEmphasized ? Palette.selectedEmphasizedText : Palette.textPrimary)
                    .lineLimit(1)

                Text(match.directory)
                    .font(Typo.label)
                    .foregroundStyle(
                        isEmphasized
                            ? Palette.selectedEmphasizedText.opacity(0.75)
                            : Palette.textTertiary
                    )
                    .lineLimit(1)
                    .truncationMode(.head)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, Metrics.spacing)
            .frame(height: Metrics.rowHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(match.path)
        .rowBackground(isSelected: isSelected, isHovered: isHovered, isFocused: true)
        .onHover { hovering in
            isHovered = hovering
            if hovering { onHover() }
        }
    }

    private var isEmphasized: Bool {
        isSelected && activeState != .inactive
    }
}
