import SwiftUI
import Core

struct StartProjectConsequenceBlock: View {
    var said: ProjectConsequence
    var home: String
    var onUseAlternative: ((String) -> Void)?

    private static let minHeight: CGFloat = 52
    private static let excludedShown = 8

    var body: some View {
        HStack(alignment: .top, spacing: Metrics.spacingWide) {
            Image(systemName: Self.symbol(for: said.tone))
                .font(Typo.caption)
                .foregroundStyle(Self.ink(for: said.tone))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Metrics.spacingTight) {
                if let lead = said.lead {
                    Text(lead)
                        .font(Typo.codeSmall)
                        .foregroundStyle(Palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }

                Text(said.detail)
                    .font(Typo.caption)
                    .foregroundStyle(
                        said.tone == .waiting ? Palette.textTertiary : Palette.textSecondary
                    )
                    .fixedSize(horizontal: false, vertical: true)

                if !said.excluded.isEmpty { excluded(said.excluded) }

                if let alternative = said.alternative, let onUseAlternative {
                    Button("Use \(NewProjectPlan.display(alternative, home: home))") {
                        onUseAlternative(alternative)
                    }
                    .controlSize(.small)
                    .padding(.top, Metrics.spacingTight)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(Metrics.inset)
        .frame(maxWidth: .infinity, minHeight: Self.minHeight, alignment: .topLeading)
        .background(Palette.surfaceSunken, in: RoundedRectangle(cornerRadius: Metrics.corner))
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.corner)
                .strokeBorder(said.tone == .refusal ? Palette.negative.opacity(0.35) : .clear)
        )
    }

    private func excluded(_ paths: [ExcludedPath]) -> some View {
        VStack(alignment: .leading, spacing: Metrics.spacingTight) {
            ForEach(paths.prefix(Self.excludedShown)) { item in
                HStack(spacing: Metrics.spacingSmall) {
                    Image(systemName: item.reason == .sensitive
                        ? "key.fill" : "folder.badge.gearshape")
                        .font(Typo.codeTiny)
                        .foregroundStyle(Palette.textTertiary)
                    Text(item.path)
                        .font(Typo.codeTiny)
                        .foregroundStyle(Palette.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            if paths.count > Self.excludedShown {
                Text("and \(paths.count - Self.excludedShown) more")
                    .font(Typo.codeTiny)
                    .foregroundStyle(Palette.textTertiary)
            }
        }
        .padding(.top, Metrics.spacingTight)
    }

    private static func symbol(for tone: ProjectConsequenceTone) -> String {
        switch tone {
        case .waiting: "folder"
        case .going: "checkmark.circle.fill"
        case .caution: "exclamationmark.triangle.fill"
        case .refusal: "exclamationmark.circle.fill"
        }
    }

    private static func ink(for tone: ProjectConsequenceTone) -> Color {
        switch tone {
        case .waiting: Palette.textTertiary
        case .going: Palette.accent(beside: [.warning, .negative])
        case .caution: Palette.warning
        case .refusal: Palette.negative
        }
    }
}
