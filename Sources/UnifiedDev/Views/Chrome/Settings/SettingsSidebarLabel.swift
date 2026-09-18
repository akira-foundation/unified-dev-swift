import SwiftUI

struct SettingsSidebarLabel: View {
    var title: String
    var systemImage: String
    var tint: Color
    var glyph: Color = .white

    static let tile: CGFloat = 20
    static let glyphSize: CGFloat = 10.5
    static let gap: CGFloat = 8
    static let rowPadding: CGFloat = 3

    var body: some View {
        Label {
            Text(title)
        } icon: {
            RoundedRectangle(cornerRadius: 5.5, style: .continuous)
                .fill(tint.gradient)
                .frame(width: Self.tile, height: Self.tile)
                .overlay {
                    Image(systemName: systemImage)
                        .font(.system(size: Self.glyphSize, weight: .semibold))
                        .foregroundStyle(glyph)
                }
        }
        .labelStyle(SettingsSidebarLabelStyle())
    }
}

private struct SettingsSidebarLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: SettingsSidebarLabel.gap) {
            configuration.icon
            configuration.title
        }
        .padding(.vertical, SettingsSidebarLabel.rowPadding)
    }
}
