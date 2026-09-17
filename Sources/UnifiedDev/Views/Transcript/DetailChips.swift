import SwiftUI

struct DetailChips: View {
    var values: [String?]

    private var present: [String] {
        values.compactMap(\.self).filter { !$0.isEmpty }
    }

    var body: some View {
        if !present.isEmpty {
            Text(present.joined(separator: "  ·  "))
                .font(Typo.caption)
                .foregroundStyle(Palette.textTertiary)
        }
    }
}
