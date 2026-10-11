import Foundation

public struct TokenUsage: Sendable, Hashable, Codable {
    public var freshInput: Int
    public var cacheRead: Int
    public var cacheWriteShort: Int
    public var cacheWriteLong: Int
    public var output: Int

    public init(
        freshInput: Int = 0,
        cacheRead: Int = 0,
        cacheWriteShort: Int = 0,
        cacheWriteLong: Int = 0,
        output: Int = 0
    ) {
        self.freshInput = freshInput
        self.cacheRead = cacheRead
        self.cacheWriteShort = cacheWriteShort
        self.cacheWriteLong = cacheWriteLong
        self.output = output
    }

    public static let none = TokenUsage()

    public var cacheWrite: Int { cacheWriteShort + cacheWriteLong }

    public var prompt: Int { freshInput + cacheRead + cacheWrite }

    public var total: Int { prompt + output }

    public var isEmpty: Bool { total == 0 }

    public static func + (left: TokenUsage, right: TokenUsage) -> TokenUsage {
        TokenUsage(
            freshInput: left.freshInput + right.freshInput,
            cacheRead: left.cacheRead + right.cacheRead,
            cacheWriteShort: left.cacheWriteShort + right.cacheWriteShort,
            cacheWriteLong: left.cacheWriteLong + right.cacheWriteLong,
            output: left.output + right.output
        )
    }

    public static func += (left: inout TokenUsage, right: TokenUsage) {
        left = left + right
    }

    static func sum(_ usages: some Sequence<TokenUsage>) -> TokenUsage {
        usages.reduce(.none, +)
    }
}
