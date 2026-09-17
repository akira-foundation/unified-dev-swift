import SwiftUI

struct WorkspaceSetupOptionGallery: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.gutter) {
            WorkspaceSetupOption(isEnabled: .constant(true))
            WorkspaceSetupOption(isEnabled: .constant(false))
        }
        .padding(Metrics.gutter)
        .frame(width: 760)
        .background(Palette.surface)
    }
}
