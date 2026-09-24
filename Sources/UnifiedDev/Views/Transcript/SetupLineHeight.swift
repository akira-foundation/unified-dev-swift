import AppKit

@MainActor
enum SetupLineHeight {
    private static var memo: (scale: CGFloat, height: CGFloat)?

    static func height(fontScale: CGFloat) -> CGFloat {
        if let memo, memo.scale == fontScale { return memo.height }

        let size = (NSFont.preferredFont(forTextStyle: .callout).pointSize * fontScale).rounded()
        let font = NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        let height = NSLayoutManager().defaultLineHeight(for: font)
        memo = (fontScale, height)
        return height
    }
}
