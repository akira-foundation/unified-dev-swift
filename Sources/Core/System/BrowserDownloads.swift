import Foundation

public struct BrowserDownloads: Sendable, Equatable {
    public enum Decision: Sendable, Equatable {
        case save
        case refuse
        case refuseAndSay(BrowserNotice)
    }

    private var burst: BrowserBurst

    public init(limit: Int = 3, window: TimeInterval = 5) {
        burst = BrowserBurst(limit: limit, window: window)
    }

    public mutating func request(from name: String?, at now: Date = Date()) -> Decision {
        switch burst.take(at: now) {
        case .allowed: return .save
        case .refused: return .refuse
        case .refusedAndUnsaid: return .refuseAndSay(Self.notice(from: name))
        }
    }

    private static func notice(from name: String?) -> BrowserNotice {
        let who = name ?? "That page"
        return BrowserNotice(
            title: "Unified Dev stopped \(who) downloading more files",
            message: """
                This page started several downloads at once, which is what a page in a loop does. \
                Unified Dev kept the first few and refused the rest. What did arrive is in your \
                Downloads folder.
                """
        )
    }
}
