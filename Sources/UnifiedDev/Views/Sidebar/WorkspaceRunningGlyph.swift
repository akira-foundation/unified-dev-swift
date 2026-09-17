import SwiftUI
import Core

struct WorkspaceRunningGlyph: View {
    var isOnSelection = false

    static let box: CGFloat = Metrics.glyph

    static let diameter: CGFloat = Metrics.dot

    private var tint: Color { isOnSelection ? Palette.textInverted : Palette.running }

    var body: some View {
        PulsingDot(diameter: Self.diameter, tint: tint)
            .frame(width: Self.box, height: Self.box)
    }
}
