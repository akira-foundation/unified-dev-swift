import SwiftUI

struct MenuPanel<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .clipShape(RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous))
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous)
                .stroke(Palette.border, lineWidth: Metrics.outline)
        }
        .elevation(.lifted)
    }
}
