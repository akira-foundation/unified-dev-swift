import SwiftUI

private struct TranscriptFoldCountKey: EnvironmentKey {
    static let defaultValue: Int? = nil
}

extension EnvironmentValues {
    var transcriptFoldCount: Int? {
        get { self[TranscriptFoldCountKey.self] }
        set { self[TranscriptFoldCountKey.self] = newValue }
    }
}

struct TranscriptGlyph: View {
    var symbol: String
    var tint: Color = Palette.textTertiary
    @Environment(\.transcriptFoldCount) private var foldCount

    var body: some View {
        Group {
            if let foldCount {
                ZStack {
                    Circle()
                        .fill(Palette.textTertiary.opacity(0.16))

                    Text(foldCount, format: .number)
                        .font(Typo.micro)
                        .fontWeight(.semibold)
                        .foregroundStyle(Palette.textTertiary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .padding(2)
                }
                .frame(width: 18, height: 18)
            } else {
                Image(systemName: symbol)
                    .font(Typo.label)
                    .imageScale(.small)
                    .foregroundStyle(tint)
            }
        }
        .frame(width: TranscriptLayout.glyphWidth, alignment: .center)
        .accessibilityHidden(true)
    }
}
