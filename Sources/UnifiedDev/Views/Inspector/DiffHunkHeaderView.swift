import SwiftUI

struct DiffHunkHeaderView: View {
    var text: String
    var width: CGFloat

    var body: some View {
        HStack(spacing: InspectorLayout.gap) {
            Image(systemName: "curlybraces")
                .font(Typo.micro)
                .imageScale(.small)
                .accessibilityHidden(true)
            Text(text)
                .font(Typo.codeTiny)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
        .foregroundStyle(Palette.textTertiary)
        .padding(.horizontal, CodeMetrics.textInset)
        .frame(width: width, height: CodeMetrics.rowHeight, alignment: .leading)
        .background(Palette.surfaceSunken)
    }
}
