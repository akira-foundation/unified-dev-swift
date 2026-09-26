import Foundation

public struct WelcomeHighlight: Sendable, Hashable, Identifiable {
    public let symbol: String
    public let headline: String
    public let detail: String

    public var id: String { symbol }

    public init(symbol: String, headline: String, detail: String) {
        self.symbol = symbol
        self.headline = headline
        self.detail = detail
    }

    public static let all: [WelcomeHighlight] = [
        WelcomeHighlight(
            symbol: "arrow.triangle.branch",
            headline: "Every task gets its own worktree",
            detail: "Real branches on disk, so two agents never trip over each other."
        ),
        WelcomeHighlight(
            symbol: "sparkles",
            headline: "Bring your own agent",
            detail: "Claude Code, Codex or Grok, chosen per workspace."
        ),
        WelcomeHighlight(
            symbol: "arrow.triangle.pull",
            headline: "Review and ship without leaving",
            detail: "The diff, the checks and the pull request are all here."
        ),
    ]
}
