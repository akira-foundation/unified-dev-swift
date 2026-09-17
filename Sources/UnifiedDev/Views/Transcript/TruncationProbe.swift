import SwiftUI

struct TruncationProbe: ViewModifier {
    var text: String
    var font: ScaledFont
    var isActive: Bool
    @Binding var isTruncated: Bool

    @State private var drawn: CGFloat?
    @State private var whole: CGFloat?

    func body(content: Content) -> some View {
        content
            .background { given }
            .background(alignment: .leading) { ruler }
            .onChange(of: isActive) { _, active in
                guard !active else { return }
                drawn = nil
                whole = nil
                isTruncated = false
            }
    }

    @ViewBuilder
    private var given: some View {
        if isActive {
            Color.clear
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: {
                    drawn = $0
                    report()
                }
        }
    }

    @ViewBuilder
    private var ruler: some View {
        if isActive {
            Text(text)
                .font(font)
                .lineLimit(1)
                .fixedSize()
                .hidden()
                .accessibilityHidden(true)
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: {
                    whole = $0
                    report()
                }
        }
    }

    private func report() {
        guard isActive, let drawn, let whole, drawn > 0 else { return }
        let cut = whole > drawn + 0.5
        if cut != isTruncated { isTruncated = cut }
    }
}

extension View {
    func reportsTruncation(
        of text: String,
        font: ScaledFont,
        isActive: Bool,
        into isTruncated: Binding<Bool>
    ) -> some View {
        modifier(
            TruncationProbe(text: text, font: font, isActive: isActive, isTruncated: isTruncated)
        )
    }
}
