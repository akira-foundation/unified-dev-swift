import SwiftUI

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
