import Core
import SwiftUI

struct TranscriptRowEnvironment: Equatable {
    let app: AppModel
    let hoverHost: TranscriptHoverHost
    let bubbleWidth: TranscriptBubbleWidth
    let linkActions: TranscriptLinkActions
    let fontScale: CGFloat
    let chatFont: ChatFont
    let lineHeight: ChatLineHeight
    let reduceMotion: Bool

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.app === rhs.app
            && lhs.hoverHost === rhs.hoverHost
            && lhs.bubbleWidth === rhs.bubbleWidth
            && lhs.linkActions == rhs.linkActions
            && lhs.fontScale == rhs.fontScale
            && lhs.chatFont == rhs.chatFont
            && lhs.lineHeight == rhs.lineHeight
            && lhs.reduceMotion == rhs.reduceMotion
    }

    func wraps(differentlyFrom other: Self) -> Bool {
        fontScale != other.fontScale
            || chatFont != other.chatFont
            || lineHeight != other.lineHeight
            || app !== other.app
            || bubbleWidth !== other.bubbleWidth
    }
}

extension View {
    func transcriptRowEnvironment(_ values: TranscriptRowEnvironment) -> some View {
        environment(values.app)
            .environment(\.transcriptHoverHost, values.hoverHost)
            .environment(\.transcriptBubbleWidth, values.bubbleWidth)
            .markdownLinkActions(values.linkActions)
            .environment(\.fontScale, values.fontScale)
            .environment(\.chatFont, values.chatFont)
            .environment(\.chatLineHeight, values.lineHeight)
    }
}
