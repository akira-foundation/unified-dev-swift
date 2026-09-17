import Foundation

public enum TranscriptTail {
    public static let length = 80

    public static func start<Kinds: RandomAccessCollection>(
        in kinds: Kinds, length: Int = length
    ) -> Int where Kinds.Element == MessageKind, Kinds.Index == Int {
        let count = kinds.count
        guard length > 0, count > length else { return 0 }

        let first = kinds.startIndex
        let cut = count - length
        let reach = max(0, cut - length)
        var index = cut
        while index > reach {
            if kinds[first + index - 1] == .result { return index }
            index -= 1
        }
        return cut
    }
}
