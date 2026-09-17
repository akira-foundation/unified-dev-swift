import Foundation

public enum DiffRunGrouping {
    public enum Chunk: Equatable, Sendable {
        case single(Int)
        case run(Range<Int>)
    }

    public static let runLimit = 400

    public static func chunks(
        count: Int,
        isLine: (Int) -> Bool,
        limit: Int = runLimit
    ) -> [Chunk] {
        let limit = max(2, limit)
        var chunks: [Chunk] = []
        var index = 0

        while index < count {
            guard isLine(index) else {
                chunks.append(.single(index))
                index += 1
                continue
            }

            var end = index
            while end < count, isLine(end), end - index < limit { end += 1 }

            if end - index == 1 {
                chunks.append(.single(index))
            } else {
                chunks.append(.run(index..<end))
            }
            index = end
        }

        return chunks
    }
}
