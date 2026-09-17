import SwiftUI
import Core

struct TranscriptResultRow: View {
    var result: TranscriptWorkspaceMatches
    var workspace: Workspace?
    var repo: Repo?
    var isArchived: Bool
    var openWorkspace: () -> Void
    var openMatch: (TranscriptMatch) -> Void

    @State private var hoveredMatch: Int64?

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingTight) {
            Button(action: openWorkspace) {
                HStack(alignment: .top, spacing: Metrics.spacingWide) {
                    RepoIcon(repo: repo)

                    VStack(alignment: .leading, spacing: Metrics.spacingTight) {
                        Text(workspace?.name ?? "Unknown workspace")
                            .font(Typo.bodyEmphasis)
                            .lineLimit(1)

                        HStack(spacing: Metrics.spacingSmall) {
                            if isArchived {
                                Label("Archived", systemImage: "archivebox")
                                    .labelStyle(.titleAndIcon)
                                    .foregroundStyle(Palette.textTertiary)

                                Text(verbatim: "·")
                                    .accessibilityHidden(true)
                            }

                            Text(repo?.name ?? "Unknown project")
                                .lineLimit(1)

                            Text(verbatim: "·")
                                .accessibilityHidden(true)

                            Text(matchCount)
                        }
                        .font(Typo.caption)
                        .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: Metrics.spacingWide)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            ForEach(result.matches) { match in
                Button { openMatch(match) } label: {
                    HStack(alignment: .firstTextBaseline, spacing: Metrics.spacingWide) {
                        Text(TranscriptSearch.label(for: match.kind))
                            .font(Typo.micro)
                            .foregroundStyle(Palette.textTertiary)
                            .frame(width: Self.labelWidth, alignment: .trailing)

                        Text(snippet(match.snippet))
                            .font(Typo.label)
                            .foregroundStyle(Palette.textSecondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, Metrics.spacingSmall)
                    .padding(.horizontal, Metrics.spacingSmall)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: Metrics.cornerSmall, style: .continuous)
                        .fill(hoveredMatch == match.id ? Palette.hover : .clear)
                )
                .onHoverChange { inside in
                    hoveredMatch = inside ? match.id : (hoveredMatch == match.id ? nil : hoveredMatch)
                }
                .accessibilityHint("Opens the workspace at this point in the transcript.")
            }
            .padding(.leading, Self.snippetInset)
        }
        .padding(.horizontal, Metrics.inset)
        .padding(.vertical, Metrics.spacing)
        .rowBackground(isSelected: false, isHovered: false)
    }

    private static let labelWidth: CGFloat = 62
    private static let snippetInset: CGFloat = 30

    private var matchCount: String {
        result.total == 1 ? "1 match" : "\(result.total) matches"
    }

    private func snippet(_ snippet: TranscriptSnippet) -> AttributedString {
        var built = AttributedString()
        for segment in snippet.segments {
            var run = AttributedString(segment.text)
            if segment.isMatch {
                run.inlinePresentationIntent = .stronglyEmphasized
                run.foregroundColor = Palette.textPrimary
            }
            built.append(run)
        }
        return built
    }
}
