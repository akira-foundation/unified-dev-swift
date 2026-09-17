import SwiftUI
import Core

struct SlashCommandRow: View {
    var match: SlashCommandMatch
    var isSelected: Bool
    var onPick: @MainActor () -> Void
    var onHover: @MainActor () -> Void

    @Environment(\.controlActiveState) private var activeState

    @State private var isHovered = false

    private var command: SlashCommand { match.command }

    var body: some View {
        Button(action: onPick) {
            HStack(alignment: .top, spacing: Metrics.spacing) {
                VStack(alignment: .leading, spacing: Metrics.spacingTight) {
                    HStack(spacing: Metrics.spacing) {
                        name
                            .font(Typo.codeSmall)
                            .lineLimit(1)
                            .layoutPriority(1)

                        Spacer(minLength: 0)

                        if let badge = command.badge {
                            Chip(text: badge)
                        }
                    }

                    if !command.detail.isEmpty {
                        Text(command.detail)
                            .font(Typo.caption)
                            .foregroundStyle(detailColour)
                            .lineLimit(3)
                            .truncationMode(.tail)
                    }
                }
            }
            .padding(.horizontal, Metrics.spacing)
            .padding(.vertical, Metrics.spacingSmall)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("/\(command.name)")
        .rowBackground(isSelected: isSelected, isHovered: isHovered, isConcentric: true)
        .onHover { hovering in
            isHovered = hovering
            if hovering { onHover() }
        }
    }

    private var name: Text {
        var runs = LocalizedStringKey.StringInterpolation(literalCapacity: 0, interpolationCount: 0)
        runs.appendInterpolation(Text("/").foregroundStyle(quiet))
        MatchedRuns.append(
            command.name, highlights: match.highlights, loud: loud, quiet: quiet, to: &runs
        )
        return Text(LocalizedStringKey(stringInterpolation: runs))
    }

    private var loud: Color {
        if isEmphasized { return Palette.selectedEmphasizedText }
        return command.kind == .skill ? Palette.accent : Palette.textPrimary
    }

    private var quiet: Color {
        if isEmphasized { return Palette.selectedEmphasizedText.opacity(0.72) }
        return command.kind == .skill ? Palette.accent.opacity(0.76) : Palette.textSecondary
    }

    private var detailColour: Color {
        isEmphasized
            ? Palette.selectedEmphasizedText.opacity(0.88)
            : Palette.textPrimary.opacity(0.68)
    }

    private var isEmphasized: Bool {
        isSelected && activeState != .inactive
    }
}
