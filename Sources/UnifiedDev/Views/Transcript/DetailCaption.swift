import SwiftUI

struct DetailCaption: View {
    var text: String

    var body: some View {
        if !text.isEmpty {
            Text(text)
                .font(Typo.label)
                .foregroundStyle(Palette.textSecondary)
        }
    }
}
