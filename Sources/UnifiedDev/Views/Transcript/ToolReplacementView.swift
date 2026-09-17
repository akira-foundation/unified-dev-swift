import SwiftUI

struct ToolReplacementView: View {
    var old: String?
    var new: String?

    var body: some View {
        VStack(alignment: .leading, spacing: TranscriptLayout.tight) {
            if let old, !old.isEmpty {
                DetailCodeBlock(text: old, tint: Palette.diffDeleteBackground)
            }
            if let new, !new.isEmpty {
                DetailCodeBlock(text: new, tint: Palette.diffAddBackground)
            }
        }
    }
}
