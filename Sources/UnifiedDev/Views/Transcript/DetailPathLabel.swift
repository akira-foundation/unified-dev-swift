import SwiftUI

struct DetailPathLabel: View {
    var path: String

    var body: some View {
        Text(path)
            .font(Typo.codeSmall)
            .foregroundStyle(Palette.textSecondary)
            .lineLimit(1)
            .truncationMode(.middle)
            .help(path)
    }
}
