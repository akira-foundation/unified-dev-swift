import SwiftUI
import Core

struct BrowserToolbarButton: View {
    var control: BrowserToolbar.Control
    var opticalOffsetY: CGFloat = 0
    var action: @MainActor () -> Void

    @Environment(\.isEnabled) private var isEnabled

    static let glyphBox: CGFloat = 16
    static let width: CGFloat = 34
    static let height: CGFloat = 28

    var body: some View {
        Button(action: action) {
            Label(control.name, systemImage: control.symbol)
                .labelStyle(.iconOnly)
                .foregroundStyle(ink)
                .offset(y: opticalOffsetY)
                .frame(width: Self.glyphBox, height: Self.glyphBox)
                .frame(width: Self.width, height: Self.height)
                .contentShape(Rectangle())
        }
        .disabled(!control.isEnabled)
        .help(control.help)
        .accessibilityAddTraits(control.isActive ? .isSelected : [])
    }

    private var ink: Color {
        guard isEnabled, control.isEnabled else { return Palette.textDisabled }
        return control.isActive ? Palette.accent : Palette.textPrimary
    }
}
