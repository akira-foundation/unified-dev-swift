import SwiftUI

/// One row of a settings source list: the pane's glyph on a filled tile, and its name.
///
/// Drawn rather than left to `Label`, because `Label` puts a bare symbol in the icon slot and no
/// style fills it. Twenty points at a five point corner with the glyph at eleven, measured off the
/// rows in System Settings.
///
/// Shared by the app's Settings window and a project's, which is the whole reason it is a type of
/// its own: the two windows are the same window about different things, and a tile drawn twice is
/// two tiles free to drift apart.
struct SettingsSidebarLabel: View {
    var title: String
    var systemImage: String
    var tint: Color

    var body: some View {
        Label {
            Text(title)
        } icon: {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(tint)
                .frame(width: 20, height: 20)
                .overlay {
                    Image(systemName: systemImage)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white)
                }
        }
    }
}
