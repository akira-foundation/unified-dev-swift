import Foundation

public struct ReleaseVersion: Comparable, Sendable, CustomStringConvertible {
    public let numbers: [Int]
    public let prerelease: String?

    public init?(_ text: String) {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("v") { trimmed.removeFirst() }

        let parts = trimmed.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        guard let core = parts.first, !core.isEmpty else { return nil }

        let numbers = core.split(separator: ".", omittingEmptySubsequences: false).map { Int($0) }
        guard (1...4).contains(numbers.count), numbers.allSatisfy({ $0 != nil }) else { return nil }

        self.numbers = numbers.compactMap(\.self)
        self.prerelease = parts.count == 2 ? String(parts[1]) : nil
        guard prerelease?.isEmpty != true else { return nil }
    }

    public var isPrerelease: Bool { prerelease != nil }

    public var description: String {
        let core = numbers.map(String.init).joined(separator: ".")
        return prerelease.map { "\(core)-\($0)" } ?? core
    }

    public static func < (lhs: ReleaseVersion, rhs: ReleaseVersion) -> Bool {
        let width = max(lhs.numbers.count, rhs.numbers.count)
        let left = lhs.numbers + Array(repeating: 0, count: width - lhs.numbers.count)
        let right = rhs.numbers + Array(repeating: 0, count: width - rhs.numbers.count)
        if left != right { return left.lexicographicallyPrecedes(right) }

        switch (lhs.prerelease, rhs.prerelease) {
        case (nil, nil), (nil, .some): return false
        case (.some, nil): return true
        case (.some(let left), .some(let right)): return left.compare(right, options: .numeric) == .orderedAscending
        }
    }

    public static func == (lhs: ReleaseVersion, rhs: ReleaseVersion) -> Bool {
        !(lhs < rhs) && !(rhs < lhs)
    }
}
