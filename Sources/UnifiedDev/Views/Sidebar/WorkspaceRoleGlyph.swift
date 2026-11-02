import SwiftUI
import Core

struct WorkspaceRoleGlyph: View {
    var symbol: String
    var isOnSelection = false

    var body: some View {
        Image(systemName: symbol)
            .font(Typo.caption)
            .fontWeight(.semibold)
            .imageScale(.medium)
            .foregroundStyle(isOnSelection ? AnyShapeStyle(Palette.textInverted) : AnyShapeStyle(Palette.accent))
            .frame(width: Metrics.glyph, height: Metrics.glyph)
            .accessibilityLabel("Orchestrator")
    }
}
