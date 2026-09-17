import SwiftUI

struct DiffExpanderView: View {
    var title: String
    var width: CGFloat
    var action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: InspectorLayout.gap) {
                Image(systemName: "chevron.up.chevron.down")
                    .font(Typo.micro)
                    .imageScale(.small)
                    .foregroundStyle(Palette.accent)
                    .accessibilityHidden(true)
                Text(title)
                    .font(Typo.codeTiny)
                    .foregroundStyle(isHovered ? Palette.accent : Palette.textTertiary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, CodeMetrics.textInset)
            .frame(width: width, height: CodeMetrics.rowHeight, alignment: .leading)
            .background(isHovered ? Palette.hover : .clear)
            .background(Palette.surfaceSunken)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
