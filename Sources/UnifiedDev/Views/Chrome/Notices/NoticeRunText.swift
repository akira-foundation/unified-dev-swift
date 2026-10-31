import SwiftUI
import Core

extension Text {
    init(runs: [NoticeRun], rung: ScaledFont, scale: CGFloat) {
        var sentence = AttributedString()
        for piece in runs {
            var part = AttributedString(piece.text)
            part.font = piece.isMachine
                ? rung.monospacedCompanion(scale: scale)
                : rung.resolved(scale: scale)
            sentence += part
        }
        self.init(sentence)
    }
}
