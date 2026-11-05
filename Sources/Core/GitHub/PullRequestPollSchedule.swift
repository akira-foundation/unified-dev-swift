import Foundation

public struct PullRequestPollSchedule: Sendable {
    public struct Row: Sendable, Equatable {
        public let id: WorkspaceID
        public let branch: String
        public let hasDiff: Bool
        public let hasKnownPullRequest: Bool
        public let isDrawn: Bool

        public init(id: WorkspaceID, branch: String, hasDiff: Bool, hasKnownPullRequest: Bool, isDrawn: Bool) {
            self.id = id
            self.branch = branch
            self.hasDiff = hasDiff
            self.hasKnownPullRequest = hasKnownPullRequest
            self.isDrawn = isDrawn
        }

        public init(_ workspace: Workspace, hasReadPullRequest: Bool, isDrawn: Bool) {
            self.init(
                id: workspace.id,
                branch: workspace.branch,
                hasDiff: workspace.hasDiff,
                hasKnownPullRequest: hasReadPullRequest || workspace.pullRequestNumber != nil,
                isDrawn: isDrawn
            )
        }

        fileprivate var isWorthAsking: Bool { hasDiff || hasKnownPullRequest }

        fileprivate var question: Question { Question(branch: branch, hasDiff: hasDiff) }
    }

    fileprivate struct Question: Sendable, Equatable {
        let branch: String
        let hasDiff: Bool
    }

    private struct Asked: Sendable {
        let question: Question
        let moment: Date
    }

    public static let tick: TimeInterval = 5

    public static let drawnInterval: TimeInterval = 120

    public static let offScreenInterval: TimeInterval = 300

    public static let offScreenPerTick = 1

    private var asked: [WorkspaceID: Asked] = [:]

    public init() {}

    public mutating func due(rows: [Row], now: Date) -> [WorkspaceID] {
        let listed = Set(rows.map(\.id))
        asked = asked.filter { listed.contains($0.key) }

        let worthAsking = rows.filter(\.isWorthAsking)
        let drawn = worthAsking.filter { $0.isDrawn && isDue($0, every: Self.drawnInterval, now: now) }
        let offScreen = worthAsking
            .filter { !$0.isDrawn && isDue($0, every: Self.offScreenInterval, now: now) }
            .enumerated()
            .sorted { first, second in
                let firstAsked = lastAsked(first.element)
                let secondAsked = lastAsked(second.element)
                return firstAsked == secondAsked ? first.offset < second.offset : firstAsked < secondAsked
            }
            .prefix(Self.offScreenPerTick)
            .map(\.element)

        let chosen = drawn + offScreen
        for row in chosen {
            asked[row.id] = Asked(question: row.question, moment: now)
        }
        return chosen.map(\.id)
    }

    private func isDue(_ row: Row, every interval: TimeInterval, now: Date) -> Bool {
        guard let last = asked[row.id], last.question == row.question else { return true }
        return now.timeIntervalSince(last.moment) >= interval
    }

    private func lastAsked(_ row: Row) -> Date {
        guard let last = asked[row.id], last.question == row.question else { return .distantPast }
        return last.moment
    }
}
