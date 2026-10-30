import SwiftUI
import Core

struct SidebarLegend: View {
    private static let width: CGFloat = 240

    private static let local = SidebarMarkPolicy.drawnInTheWorkspace
    private static let remote = SidebarMarkPolicy.drawnOnGitHub

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingWide) {
            section("In the workspace", states: Self.local)
            section("On GitHub", states: Self.remote)
        }
        .padding(Metrics.gutter)
        .frame(width: Self.width)
    }

    private func section(_ title: String, states: [WorkspaceStatus]) -> some View {
        VStack(alignment: .leading, spacing: Metrics.spacingSmall) {
            Text(title)
                .font(Typo.captionEmphasis)
                .foregroundStyle(Palette.textSecondary)
                .accessibilityAddTraits(.isHeader)

            ForEach(states, id: \.self) { status in
                HStack(spacing: Metrics.spacingWide) {
                    WorkspaceStatusGlyph(status: status)
                        .accessibilityHidden(true)
                    Text(status.label)
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textPrimary)
                    Spacer(minLength: 0)
                }
            }
        }
    }
}
