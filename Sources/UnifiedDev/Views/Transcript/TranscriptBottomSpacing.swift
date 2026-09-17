import SwiftUI
import Core

extension TranscriptTableEntry {
    static var bottomSpacing: Self {
        bottomSpacing(clearance: 0)
    }

    static func bottomSpacing(clearance: CGFloat) -> Self {
        let height = max(TranscriptLayout.block, clearance)
        return Self(
            id: .bottomSpacing,
            contentKey: TranscriptContentKey {
                $0.combine("bottomSpacing")
                $0.combine(height)
            },
            content: {
                AnyView(Color.clear.frame(height: height).accessibilityHidden(true))
            }
        )
    }
}
