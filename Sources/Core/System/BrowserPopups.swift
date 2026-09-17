import Foundation

public struct BrowserPopups: Sendable, Equatable {
    public typealias Notice = BrowserNotice

    public enum Decision: Sendable, Equatable {
        case open(URL)
        case refuse
        case refuseAndSay(Notice)
    }

    private var burst: BrowserBurst

    public init(limit: Int = 5, window: TimeInterval = 5) {
        burst = BrowserBurst(limit: limit, window: window)
    }

    public mutating func request(_ url: URL?, at now: Date = Date()) -> Decision {
        guard let url, BrowserAddress.shows(url) else { return .refuse }

        switch burst.take(at: now) {
        case .allowed: return .open(url)
        case .refused: return .refuse
        case .refusedAndUnsaid: return .refuseAndSay(Self.notice(for: url))
        }
    }

    private static func notice(for url: URL) -> Notice {
        let host = url.host() ?? "That page"
        return Notice(
            title: "Unified Dev stopped \(host) opening more tabs",
            message: """
                This page asked for several browser tabs at once, which is what a page in a loop \
                does. Unified Dev opened the first few and refused the rest. Reload the page if you were \
                expecting them.
                """
        )
    }
}
