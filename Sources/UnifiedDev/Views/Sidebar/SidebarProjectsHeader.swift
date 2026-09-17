import SwiftUI
import Core

struct SidebarProjectsHeader: View {
    var onStartProject: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: Metrics.spacing) {
            Text("Projects")
                .font(Typo.captionEmphasis)
                .foregroundStyle(Palette.textSecondary)
                .accessibilityAddTraits(.isHeader)

            Spacer(minLength: Metrics.spacingSmall)

            Button(action: onStartProject) {
                Label(MenuBarCatalogue[.startProject].title, systemImage: "folder.badge.plus")
                    .labelStyle(.iconOnly)
                    .font(Typo.label)
            }
            .buttonStyle(.plain)
            .contentShape(Circle())
            .foregroundStyle(isHovered ? Palette.textPrimary : Palette.textSecondary)
            .help("Start a project (⌥⌘N)")
        }
        .contentShape(Rectangle())
        .onHoverChange { isHovered = $0 }
    }
}
