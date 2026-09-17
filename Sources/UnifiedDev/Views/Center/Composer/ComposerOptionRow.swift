import SwiftUI

struct ComposerOptionRow: View {
    var option: ComposerOption
    var isSelected: Bool
    var isHighlighted: Bool
    var onPick: @MainActor () -> Void
    var onHover: @MainActor () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onPick) {
            HStack(alignment: .firstTextBaseline, spacing: Metrics.spacing) {
                Image(systemName: "checkmark")
                    .font(Typo.label)
                    .foregroundStyle(Palette.accent)
                    .opacity(isSelected ? 1 : 0)
                    .frame(width: Metrics.glyph, alignment: .leading)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: Metrics.spacingTight) {
                    Text(option.label)
                        .font(Typo.label)
                        .foregroundStyle(Palette.textPrimary)
                        .lineLimit(1)

                    if let detail = option.detail, !detail.isEmpty {
                        Text(detail)
                            .font(Typo.caption)
                            .foregroundStyle(Palette.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, Metrics.spacing)
            .padding(.vertical, Metrics.spacingWide)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.label)
        .accessibilityValue(option.detail ?? "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .rowBackground(isSelected: isHighlighted, isHovered: isHovered, isFocused: false)
        .onHover { hovering in
            isHovered = hovering
            if hovering { onHover() }
        }
    }
}
