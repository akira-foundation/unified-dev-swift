import Foundation

public enum TranscriptPointer: Sendable, Hashable {
    case hand
    case text
    case arrow

    public static func over(link: Bool, chipThatOpens: Bool) -> TranscriptPointer {
        link || chipThatOpens ? .hand : .text
    }

    public static func overChrome(selectableText: Bool) -> TranscriptPointer {
        selectableText ? .text : .arrow
    }
}
