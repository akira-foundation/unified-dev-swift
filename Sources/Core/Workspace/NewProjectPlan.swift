import Foundation

public struct NewProjectFacts: Sendable, Equatable {
    public var name: String
    public var location: String
    public var path: String
    public var locationExists: Bool
    public var targetExists: Bool
    public var targetIsDirectory: Bool
    public var targetIsEmpty: Bool
    public var targetIsRepository: Bool
    public var enclosingRepository: String?
    public var nearestExistingAncestor: String
    public var isAncestorWritable: Bool
    public var isTargetWritable: Bool
    public var homeDirectory: String
    public var workspacesRoot: String
    public var childRepositories: [String]
    public var gitProblem: GitRepositoryProblem?

    public init(
        name: String = "",
        location: String = "",
        path: String = "",
        locationExists: Bool = false,
        targetExists: Bool = false,
        targetIsDirectory: Bool = false,
        targetIsEmpty: Bool = false,
        targetIsRepository: Bool = false,
        enclosingRepository: String? = nil,
        nearestExistingAncestor: String = "",
        isAncestorWritable: Bool = true,
        isTargetWritable: Bool = true,
        homeDirectory: String = "",
        workspacesRoot: String = "",
        childRepositories: [String] = [],
        gitProblem: GitRepositoryProblem? = nil
    ) {
        self.name = name
        self.location = location
        self.path = path
        self.locationExists = locationExists
        self.targetExists = targetExists
        self.targetIsDirectory = targetIsDirectory
        self.targetIsEmpty = targetIsEmpty
        self.targetIsRepository = targetIsRepository
        self.enclosingRepository = enclosingRepository
        self.nearestExistingAncestor = nearestExistingAncestor
        self.isAncestorWritable = isAncestorWritable
        self.isTargetWritable = isTargetWritable
        self.homeDirectory = homeDirectory
        self.workspacesRoot = workspacesRoot
        self.childRepositories = childRepositories
        self.gitProblem = gitProblem
    }
}

extension NewProjectFacts {
    var folderFacts: FolderFacts {
        FolderFacts(
            path: path,
            isRepository: targetIsRepository,
            repositoryRoot: targetIsRepository ? path : nil,
            enclosingRepository: targetIsRepository ? nil : enclosingRepository,
            isWritable: isTargetWritable,
            isDirectory: targetIsDirectory,
            exists: targetExists,
            isAbsolute: !path.isEmpty,
            homeDirectory: homeDirectory,
            workspacesRoot: workspacesRoot,
            childRepositories: childRepositories,
            gitProblem: targetIsRepository ? gitProblem : nil
        )
    }
}

public enum NewProjectRefusal: Sendable, Equatable {
    case noName
    case nameHasSeparator(String)
    case nameIsHidden(String)
    case noLocation
    case locationNotAbsolute(String)
    case somethingThere(String)
    case insideRepository(String)
    case insideOurWorkspaces(String)
    case reservedLocation(String)
    case notWritable(String)
}

public extension NewProjectRefusal {
    var alternative: String? {
        guard case .insideRepository(let root) = self else { return nil }
        return root
    }

    var sentence: String {
        switch self {
        case .noName:
            "Give the project a name."
        case .nameHasSeparator:
            """
            A project's name is the name of its folder, and macOS reads a colon in one as a slash. \
            Pick another name, or type the whole path of the folder you mean.
            """
        case .nameIsHidden:
            """
            A name starting with a dot makes a folder the Finder hides, which is not somewhere a \
            project can be worked in. Pick another name.
            """
        case .noLocation:
            "Choose where the project should live."
        case .locationNotAbsolute(let path):
            "Unified Dev cannot tell where '\(path)' is, because it is not a full path."
        case .somethingThere(let path):
            "There is already a file called \(path). Pick another name."
        case .insideRepository(let root):
            """
            That location is inside the git repository at \(root). Starting another repository \
            here would nest one inside the other, which git cannot check out again. Add \(root) \
            instead, or pick a folder outside it.
            """
        case .insideOurWorkspaces(let path):
            """
            \(path) is inside the folder Unified Dev cuts its own worktrees into. A project lives where \
            you keep your own work, and Unified Dev makes the worktrees from it.
            """
        case .reservedLocation(let path):
            """
            \(path) is one of your Mac's own folders, so a repository there would track far more \
            than a project. Pick somewhere your projects live.
            """
        case .notWritable(let path):
            "Unified Dev cannot write to \(path), so it cannot create the project folder there."
        }
    }
}

public enum NewProjectVerdict: Sendable, Equatable {
    case create(makesLocation: Bool)
    case adopt
    case refuse(NewProjectRefusal)
}

public extension NewProjectVerdict {
    static func of(_ facts: NewProjectFacts) -> NewProjectVerdict {
        let name = NewProjectPlan.folderName(from: facts.name)
        guard !name.isEmpty else { return .refuse(.noName) }
        if name.contains("/") || name.contains(":") { return .refuse(.nameHasSeparator(name)) }
        if name.hasPrefix(".") { return .refuse(.nameIsHidden(name)) }

        let location = facts.location.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !location.isEmpty else { return .refuse(.noLocation) }
        guard !facts.path.isEmpty else { return .refuse(.locationNotAbsolute(location)) }

        func shown(_ path: String) -> String {
            NewProjectPlan.display(path, home: facts.homeDirectory)
        }

        if FolderPath.isInside(facts.path, of: facts.workspacesRoot) {
            return .refuse(.insideOurWorkspaces(shown(facts.path)))
        }
        if FolderPath.isReserved(facts.path, home: facts.homeDirectory)
            || FolderPath.sameFolder(facts.path, facts.homeDirectory) {
            return .refuse(.reservedLocation(shown(facts.path)))
        }
        if let enclosing = facts.enclosingRepository {
            return .refuse(.insideRepository(shown(enclosing)))
        }

        if facts.targetExists {
            guard facts.targetIsDirectory else { return .refuse(.somethingThere(shown(facts.path))) }
            guard facts.isTargetWritable else { return .refuse(.notWritable(shown(facts.path))) }
            return .adopt
        }

        guard facts.isAncestorWritable else {
            return .refuse(.notWritable(shown(facts.nearestExistingAncestor)))
        }
        return .create(makesLocation: !facts.locationExists)
    }

    var allowsCreation: Bool {
        switch self {
        case .create, .adopt: true
        case .refuse: false
        }
    }

    func hint(path: String, home: String) -> String {
        let shown = NewProjectPlan.display(path, home: home)
        switch self {
        case .create(let makesLocation):
            return makesLocation
                ? "\(shown). Unified Dev will create both."
                : "\(shown). Unified Dev will create it."
        case .adopt:
            return "\(shown) is already there and empty, so Unified Dev will use it."
        case .refuse(let refusal):
            return refusal.sentence
        }
    }
}

public enum NewProjectPlan {
    public static let fallbackLocationName = "Developer"

    public static func suggestedLocation(projectPaths: [String], home: String) -> String {
        var counts: [String: Int] = [:]
        var order: [String] = []
        for path in projectPaths {
            let parent = (FolderPath.normalize(path) as NSString).deletingLastPathComponent
            guard parent.count > 1 else { continue }
            if counts[parent] == nil { order.append(parent) }
            counts[parent, default: 0] += 1
        }
        let commonest = order.max { (counts[$0] ?? 0) < (counts[$1] ?? 0) }
        return commonest ?? (FolderPath.normalize(home) as NSString)
            .appendingPathComponent(fallbackLocationName)
    }

    public static func projectsIn(_ location: String, projectPaths: [String]) -> Int {
        let folder = FolderPath.normalize(location)
        return projectPaths.count {
            (FolderPath.normalize($0) as NSString).deletingLastPathComponent == folder
        }
    }

    public static func folderName(from typed: String) -> String {
        typed.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func target(name: String, location: String, home: String) -> String? {
        let folder = folderName(from: name)
        guard !folder.isEmpty, !folder.contains("/") else { return nil }
        let trimmed = location.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let expanded = expand(trimmed, home: home)
        guard expanded.hasPrefix("/") else { return nil }
        return (FolderPath.normalize(expanded) as NSString).appendingPathComponent(folder)
    }

    public static func expand(_ path: String, home: String) -> String {
        let home = FolderPath.normalize(home)
        if path == "~" { return home }
        guard path.hasPrefix("~/") else { return path }
        return home + String(path.dropFirst(1))
    }

    public static func display(_ path: String, home: String) -> String {
        let home = FolderPath.normalize(home)
        let normalized = FolderPath.normalize(path)
        guard !home.isEmpty, normalized == home || normalized.hasPrefix(home + "/") else {
            return normalized
        }
        return "~" + normalized.dropFirst(home.count)
    }
}
