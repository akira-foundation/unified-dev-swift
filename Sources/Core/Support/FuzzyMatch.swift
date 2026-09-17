import Foundation

public enum FuzzyMatch {
    public struct Hit: Sendable, Hashable {
        public var score: Int
        public var positions: [Int]

        public init(score: Int, positions: [Int]) {
            self.score = score
            self.positions = positions
        }
    }

    public static func score(_ candidate: String, query: String) -> Int? {
        best(candidate, query: query, startLimit: 1)?.score
    }

    public static func hit(_ candidate: String, query: String, startLimit: Int = 24) -> Hit? {
        best(candidate, query: query, startLimit: startLimit)
    }

    private static func best(_ candidate: String, query: String, startLimit: Int) -> Hit? {
        guard !query.isEmpty else { return Hit(score: 0, positions: []) }

        let haystack = Array(candidate.lowercased())
        let needle = Array(query.lowercased())
        guard needle.count <= haystack.count else { return nil }
        let positionsAreTrustworthy = haystack.count == candidate.count

        var found: Hit?
        var tried = 0
        var start = 0

        while start < haystack.count, tried < startLimit {
            guard haystack[start] == needle[0] else {
                start += 1
                continue
            }
            tried += 1
            guard let hit = greedy(haystack, needle, from: start) else { break }
            if found == nil || hit.score > found!.score { found = hit }
            start += 1
        }

        guard let found else { return nil }
        return positionsAreTrustworthy ? found : Hit(score: found.score, positions: [])
    }

    private static func greedy(_ haystack: [Character], _ needle: [Character], from start: Int) -> Hit? {
        var total = 0
        var positions: [Int] = []
        positions.reserveCapacity(needle.count)

        var index = start
        var previousMatch = -2

        for character in needle {
            var matched = false
            while index < haystack.count {
                let current = haystack[index]
                index += 1
                guard current == character else { continue }

                let position = index - 1
                if position == previousMatch + 1 { total += 8 }
                if position == 0 { total += 12 }
                if position > 0, isBoundary(haystack[position - 1]) { total += 6 }
                total += 1
                previousMatch = position
                positions.append(position)
                matched = true
                break
            }
            if !matched { return nil }
        }

        return Hit(score: total + max(0, 40 - haystack.count), positions: positions)
    }

    private static func isBoundary(_ character: Character) -> Bool {
        character == "/" || character == "_" || character == "-"
            || character == "." || character == " " || character == ":"
    }
}
