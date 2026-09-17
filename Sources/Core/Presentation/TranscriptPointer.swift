import Foundation

public enum TranscriptPointer: Sendable, Hashable {
    case hand
    case text

    public static func over(link: Bool, chipThatOpens: Bool) -> TranscriptPointer {
        link || chipThatOpens ? .hand : .text
    }
}
