import SwiftUI
import Core

struct QuickPromptMarkView: View {
    var stored: String
    var points: CGFloat
    var tint: Color = Palette.textSecondary

    private static let emojiScale: CGFloat = 0.86
    private static let emojiRise: CGFloat = 0.06

    var body: some View {
        Group {
            switch QuickPromptMark(stored: stored) {
            case .symbol(let name):
                Image(systemName: name)
                    .font(.system(size: points))
                    .foregroundStyle(tint)
            case .emoji(let emoji):
                Text(emoji)
                    .font(.system(size: points * Self.emojiScale))
                    .offset(y: points * Self.emojiRise)
            }
        }
        .frame(width: points, height: points)
    }
}
