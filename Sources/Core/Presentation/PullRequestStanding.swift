import Foundation

public struct PullRequestStanding: Sendable, Hashable {
    public enum Tone: String, Sendable, Hashable, CaseIterable {
        case quiet
        case accent
        case danger
        case warning
        case merged
    }

    public enum Act: String, Sendable, Hashable, CaseIterable {
        case openPullRequest
        case push
        case commitAndPush
        case markReadyForReview
        case merge
        case askToFixChecks
        case askToFixConflicts
        case archive

        public var label: String {
            switch self {
            case .openPullRequest: "Open PR"
            case .push, .commitAndPush: "Push"
            case .markReadyForReview: "Mark ready"
            case .merge: "Merge"
            case .askToFixChecks, .askToFixConflicts: "Ask to fix"
            case .archive: "Archive"
            }
        }

        public var writesToComposer: Bool {
            self == .askToFixChecks || self == .askToFixConflicts
        }
    }

    public struct Button: Sendable, Hashable {
        public var act: Act
        public var sentence: String

        public init(act: Act, sentence: String) {
            self.act = act
            self.sentence = sentence
        }

        public var label: String { act.label }
    }

    public var headline: String
    public var target: String?
    public var number: Int?
    public var url: String?
    public var state: String?
    public var tone: Tone
    public var ahead: String?
    public var aheadAnnouncement: String?
    public var note: String?
    public var button: Button?
    public var current: PullRequestStep?
    public var path: [PullRequestStep]
    public var links: [PullRequestStepLink]
    public var sentence: String

    public init(
        headline: String,
        target: String? = nil,
        number: Int? = nil,
        url: String? = nil,
        state: String? = nil,
        tone: Tone = .quiet,
        ahead: String? = nil,
        aheadAnnouncement: String? = nil,
        note: String? = nil,
        button: Button? = nil,
        current: PullRequestStep? = nil,
        path: [PullRequestStep] = [],
        links: [PullRequestStepLink] = [],
        sentence: String = ""
    ) {
        self.headline = headline
        self.target = target
        self.number = number
        self.url = url
        self.state = state
        self.tone = tone
        self.ahead = ahead
        self.aheadAnnouncement = aheadAnnouncement
        self.note = note
        self.button = button
        self.current = current
        self.path = path
        self.links = links
        self.sentence = sentence
    }

    public func reach(of step: PullRequestStep) -> PullRequestReach? {
        links.first { $0.step == step }?.reach
    }

    public func announcement(of step: PullRequestStep) -> String? {
        links.first { $0.step == step }?.announcement
    }

    public static let labelledWidth: CGFloat = 420

    public static func showsLabels(atWidth width: CGFloat) -> Bool {
        width >= labelledWidth
    }

    public static func aheadMark(_ count: Int, isCapped: Bool = false) -> String? {
        guard count > 0 else { return nil }
        return isCapped ? "\(count)+ \u{2191}" : "\(count) \u{2191}"
    }

    public static func aheadSentence(_ count: Int, base: String, isCapped: Bool = false) -> String? {
        guard count > 0 else { return nil }
        let number = isCapped ? "more than \(count)" : "\(count)"
        let commits = count == 1 && !isCapped ? "commit" : "commits"
        return "\(number) \(commits) ahead of \(base)"
    }
}
