import Foundation

public struct ProjectTarget: Sendable, Equatable {
    public var name: String
    public var location: String

    public init(name: String, location: String) {
        self.name = name
        self.location = location
    }
}

public extension ProjectTarget {
    static func looksLikeAPath(_ typed: String) -> Bool {
        typed.contains("/") || typed.hasPrefix("~")
    }

    static func resolve(
        _ typed: String,
        defaultLocation: String,
        home: String
    ) -> ProjectTarget {
        let trimmed = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard looksLikeAPath(trimmed) else {
            return ProjectTarget(name: trimmed, location: defaultLocation)
        }
        let expanded = NewProjectPlan.expand(trimmed, home: home)
        let normalized = FolderPath.normalize(expanded)
        return ProjectTarget(
            name: (normalized as NSString).lastPathComponent,
            location: (normalized as NSString).deletingLastPathComponent
        )
    }
}

public enum ProjectTargetRefusal: Sendable, Equatable {
    case target(NewProjectRefusal)
    case folder(FolderRefusal)

    public var sentence: String {
        switch self {
        case .target(let refusal): refusal.sentence
        case .folder(let refusal): refusal.sentence
        }
    }

    public var alternative: String? {
        switch self {
        case .target(let refusal): refusal.alternative
        case .folder(let refusal): refusal.alternative
        }
    }

    public var buttonTitle: String {
        switch self {
        case .target: ProjectTargetVerdict.createTitle
        case .folder: ProjectTargetVerdict.addTitle
        }
    }
}

public enum ProjectTargetVerdict: Sendable, Equatable {
    case create(makesLocation: Bool)
    case adopt
    case add(root: String)
    case track
    case refuse(ProjectTargetRefusal)
}

public extension ProjectTargetVerdict {
    static let createTitle = "Create Project"
    static let addTitle = "Add Project"
    static let trackTitle = "Start Tracking"

    static func of(_ facts: NewProjectFacts) -> ProjectTargetVerdict {
        if facts.targetExists, facts.targetIsDirectory, !facts.targetIsEmpty {
            switch FolderVerdict.of(facts.folderFacts) {
            case .alreadyRepository(let root): return .add(root: root)
            case .offer: return .track
            case .refuse(let refusal): return .refuse(.folder(refusal))
            }
        }
        switch NewProjectVerdict.of(facts) {
        case .create(let makesLocation): return .create(makesLocation: makesLocation)
        case .adopt: return .adopt
        case .refuse(let refusal): return .refuse(.target(refusal))
        }
    }

    var isAllowed: Bool {
        if case .refuse = self { return false }
        return true
    }

    var makesACommit: Bool {
        switch self {
        case .create, .adopt, .track: true
        case .add, .refuse: false
        }
    }

    var opensAWorkspace: Bool {
        switch self {
        case .create, .adopt: true
        case .add, .track, .refuse: false
        }
    }

    var buttonTitle: String {
        switch self {
        case .create, .adopt: Self.createTitle
        case .add: Self.addTitle
        case .track: Self.trackTitle
        case .refuse(let refusal): refusal.buttonTitle
        }
    }
}

public enum ProjectConsequenceTone: Sendable, Equatable {
    case waiting
    case going
    case caution
    case refusal
}

public struct ProjectConsequence: Sendable, Equatable {
    public var lead: String?
    public var detail: String
    public var tone: ProjectConsequenceTone
    public var excluded: [ExcludedPath]
    public var alternative: String?

    public init(
        lead: String? = nil,
        detail: String,
        tone: ProjectConsequenceTone,
        excluded: [ExcludedPath] = [],
        alternative: String? = nil
    ) {
        self.lead = lead
        self.detail = detail
        self.tone = tone
        self.excluded = excluded
        self.alternative = alternative
    }
}

public extension ProjectConsequence {
    static func opening(location: String, projectsThere: Int, home: String) -> ProjectConsequence {
        let shown = NewProjectPlan.display(location, home: home)
        let placement = switch projectsThere {
        case 0: "New projects go in \(shown)."
        case 1: "New projects go in \(shown), where your other project lives."
        default: "New projects go in \(shown), where \(projectsThere) of your projects live."
        }
        return ProjectConsequence(
            detail: placement
                + " Type a name to make one there, or point at a folder you already have.",
            tone: .waiting
        )
    }

    static func of(
        _ verdict: ProjectTargetVerdict,
        path: String,
        home: String,
        branch: String,
        contents: FolderContents? = nil
    ) -> ProjectConsequence {
        switch verdict {
        case .create(let makesLocation):
            ProjectConsequence(
                lead: NewProjectVerdict.create(makesLocation: makesLocation)
                    .hint(path: path, home: home),
                detail: firstCommit(on: branch),
                tone: .going
            )

        case .adopt:
            ProjectConsequence(
                lead: NewProjectVerdict.adopt.hint(path: path, home: home),
                detail: firstCommit(on: branch),
                tone: .going
            )

        case .add(let root):
            ProjectConsequence(
                lead: "\(NewProjectPlan.display(root, home: home)) is a git repository.",
                detail: "Unified Dev will add it as a project. Nothing is written to it and nothing in "
                    + "it is changed.",
                tone: .going
            )

        case .track:
            ProjectConsequence(
                lead: "\(NewProjectPlan.display(path, home: home)) has files in it and is not a "
                    + "repository.",
                detail: tracking(contents: contents, branch: branch),
                tone: .caution,
                excluded: contents?.excluded ?? []
            )

        case .refuse(let refusal):
            ProjectConsequence(
                detail: refusal.sentence,
                tone: .refusal,
                alternative: refusal.alternative
            )
        }
    }

    private static func firstCommit(on branch: String) -> String {
        "git init, and an empty first commit on \(branch). Unified Dev writes no files of its own: "
            + "no README, no .gitignore."
    }

    private static func tracking(contents: FolderContents?, branch: String) -> String {
        var detail = "git init, and what is already here as the first commit on \(branch)."
        guard let contents else { return detail }
        detail += " " + contents.summary
        if let excluded = contents.excludedSummary { detail += " " + excluded }
        return detail
    }
}
