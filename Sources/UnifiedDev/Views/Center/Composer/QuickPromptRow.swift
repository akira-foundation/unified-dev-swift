import SwiftUI
import Core

struct QuickPromptRow: View {
    var row: QuickPromptPanelRow
    var isSelected: Bool
    var onPick: @MainActor () -> Void
    var onHover: @MainActor () -> Void
    var onEdit: @MainActor () -> Void
    var onDelete: @MainActor () -> Void
    var onCopy: @MainActor () -> Void = {}

    @State private var isHovered = false

    var body: some View {
        Button(action: onPick) {
            HStack(spacing: Metrics.gutter) {
                QuickPromptMarkView(stored: row.symbol, points: Metrics.repoIcon)

                VStack(alignment: .leading, spacing: Metrics.spacingTight) {
                    Text(row.name)
                        .font(Typo.label)
                        .foregroundStyle(Palette.textPrimary)
                        .lineLimit(1)

                    if let secondLine = row.secondLine {
                        Text(secondLine)
                            .font(Typo.caption)
                            .foregroundStyle(Palette.textTertiary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }

                Spacer(minLength: Metrics.spacingSmall)

                trailingAction
                    .opacity(isHovered || isSelected ? 1 : 0)
                    .allowsHitTesting(isHovered || isSelected)
            }
            .padding(.horizontal, Metrics.spacing)
            .padding(.vertical, Metrics.spacingWide)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(row.name)
        .accessibilityValue(row.accessibilityValue)
        .rowBackground(isSelected: isSelected, isHovered: isHovered, isFocused: false)
        .onHover { hovering in
            isHovered = hovering
            if hovering { onHover() }
        }
        .contextMenu {
            if row.isEditable {
                Button("Edit", action: onEdit)
                Button("Delete", role: .destructive, action: onDelete)
            } else {
                Button("Copy to My Quick Prompts", action: onCopy)
            }
        }
    }

    private var trailingAction: some View {
        Button {
            if row.isEditable { onEdit() } else { onCopy() }
        } label: {
            Image(systemName: row.isEditable ? "pencil" : "doc.on.doc")
                .imageScale(.small)
                .foregroundStyle(Palette.textTertiary)
                .frame(width: Metrics.rowHeight - Metrics.spacingWide,
                       height: Metrics.rowHeight - Metrics.spacingWide)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(row.isEditable ? "Edit this quick prompt" : "Copy to My Quick Prompts")
        .accessibilityLabel(
            row.isEditable ? "Edit \(row.name)" : "Copy \(row.name) to My Quick Prompts"
        )
    }
}
