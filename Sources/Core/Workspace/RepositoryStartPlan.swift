import Foundation

public struct FolderFacts: Sendable, Equatable {
    public var path: String
    public var isRepository: Bool
    public var repositoryRoot: String?
    public var enclosingRepository: String?
    public var isWritable: Bool
    public var isDirectory: Bool
    public var exists: Bool
    public var isAbsolute: Bool
    public var homeDirectory: String
    public var workspacesRoot: String
    public var childRepositories: [String]
    public var gitProblem: GitRepositoryProblem?

    public init(
        path: String,
        isRepository: Bool,
        repositoryRoot: String? = nil,
        enclosingRepository: String? = nil,
        isWritable: Bool = true,
        isDirectory: Bool = true,
        exists: Bool = true,
        isAbsolute: Bool = true,
        homeDirectory: String,
        workspacesRoot: String = WorkspaceManager.workspacesRoot.path,
        childRepositories: [String] = [],
        gitProblem: GitRepositoryProblem? = nil
    ) {
        self.path = path
        self.isRepository = isRepository
        self.repositoryRoot = repositoryRoot
        self.enclosingRepository = enclosingRepository
        self.isWritable = isWritable
        self.isDirectory = isDirectory
        self.exists = exists
        self.isAbsolute = isAbsolute
        self.homeDirectory = homeDirectory
        self.workspacesRoot = workspacesRoot
        self.childRepositories = childRepositories
        self.gitProblem = gitProblem
    }
}

public enum FolderRefusal: Sendable, Equatable {
    case notAbsolute(String)
    case nothingThere(String)
    case notADirectory(String)

    case insideOurWorkspaces(String)
    case volumeRoot
    case homeDirectory

    case insideRepository(String)
    case systemDirectory
    case notWritable
    case containerOfProjects([String])
    case gitCannotRead(GitRepositoryProblem)
}

public extension FolderRefusal {
    static let projectContainerThreshold = 3

    var sentence: String {
        switch self {
        case .notAbsolute(let path):
            "Unified Dev cannot tell where '\(path)' is, because it is not a full path."
        case .nothingThere:
            "There is nothing at that path any more."
        case .notADirectory:
            "That is not a folder."
        case .insideOurWorkspaces(let path):
            """
            \(path) is one of Unified Dev's own workspaces, which is a worktree of a project Unified Dev \
            already has. Add the project it was cut from instead.
            """
        case .volumeRoot:
            """
            This is the root of the volume. Even where that is a git repository it is not one \
            project. Pick the project folder itself.
            """
        case .insideRepository(let root):
            """
            This folder is already inside the git repository at \(root). Starting another \
            repository here would nest one inside the other, which git cannot check out again. \
            Add \(root) instead, or pick a folder outside it.
            """
        case .homeDirectory:
            """
            This is your home folder. A repository here would track every file on your account, \
            including your keys and your mail. Pick the project folder itself.
            """
        case .systemDirectory:
            """
            This folder belongs to macOS or holds unrelated things. A repository here would track \
            all of it. Pick the project folder itself.
            """
        case .notWritable:
            "Unified Dev cannot write to this folder, so it cannot create a repository in it."
        case .containerOfProjects(let names):
            """
            This folder holds \(Self.list(names)), which are repositories of their own. It is a \
            folder of projects rather than a project. Pick one of them instead.
            """
        case .gitCannotRead(let problem):
            problem.sentence
        }
    }

    var alternative: String? {
        guard case .insideRepository(let root) = self else { return nil }
        return root
    }

    var agentSentence: String {
        switch self {
        case .notAbsolute(let path):
            """
            Unified Dev will not add '\(path)' as a project because it is not an absolute path. Unified Dev \
            is a separate application and its working directory is not yours, so a relative path \
            points somewhere neither of us can agree on. Ask again with the full path, starting \
            at / or ~.
            """

        case .nothingThere(let path):
            """
            Unified Dev will not add \(path) as a project because there is nothing at that path. Check \
            where the repository actually is and ask again with the right path. If you were \
            guessing, stop guessing and ask the owner.
            """

        case .notADirectory(let path):
            """
            Unified Dev will not add \(path) as a project because it is a file, not a folder. A project \
            is the folder holding the repository. Ask again with the folder it is in.
            """

        case .insideOurWorkspaces(let path):
            """
            Unified Dev will not add \(path) as a project because it is one of Unified Dev's own workspaces. \
            A workspace is a worktree Unified Dev already cut from a project it already has, so adding \
            it would give Unified Dev a project whose workspaces are worktrees of a worktree. Add the \
            repository it was cut from instead, if that is not already a project.
            """

        case .volumeRoot:
            Self.tooBroad("the root of the volume")

        case .homeDirectory:
            Self.tooBroad("your whole home folder")

        case .insideRepository(let root):
            """
            Unified Dev will not add that folder as a project because it sits inside the repository at \
            \(root) without being part of it. Ask again with \(root), if that is not already a \
            project. Do not run git init to make this call succeed: whether a folder should be a \
            repository is the owner's decision.
            """

        case .systemDirectory:
            """
            Unified Dev will not add that folder as a project because it belongs to macOS or holds \
            unrelated things, and it is not a git repository either. Retrying will not help and \
            neither will running git init: turning a folder into a repository is the owner's \
            decision. Ask again with the folder of the actual repository you meant.
            """

        case .notWritable:
            """
            Unified Dev will not add that folder as a project. It is not a git repository, and Unified Dev \
            cannot write to it either, so retrying will not help and neither will running git \
            init. Check the path with the owner.
            """

        case .containerOfProjects(let names):
            """
            Unified Dev will not add that folder as a project because it holds \(Self.list(names)), \
            which are repositories of their own, and is not a repository itself. It is a folder \
            of projects rather than a project. Ask again with one of them, and do not run git \
            init here: that would put every project on the machine into one repository.
            """

        case .gitCannotRead(let problem):
            problem.agentSentence
        }
    }

    static func notARepositoryForAgent(path: String) -> String {
        """
        Unified Dev will not add \(path) as a project because git does not recognise it as a \
        repository. Unified Dev registers repositories that already exist and it does not create them, \
        so retrying will not help and neither will running git init: turning a folder into a \
        repository is the owner's decision and not something to do on their behalf while tidying \
        up a project list. If this folder should be a repository, say so and let the owner make \
        it one.
        """
    }

    private static func tooBroad(_ what: String) -> String {
        """
        Unified Dev will not add that folder as a project because it is \(what). Even where that is a \
        git repository it is not one project, and every workspace cut from it would carry \
        everything inside it. Ask again with the folder of the actual repository you meant.
        """
    }

    private static func list(_ names: [String]) -> String {
        let shown = names.prefix(3).joined(separator: ", ")
        guard names.count > 3 else { return shown }
        return "\(shown) and \(names.count - 3) more"
    }
}

public enum FolderVerdict: Sendable, Equatable {
    case alreadyRepository(root: String)
    case refuse(FolderRefusal)
    case offer
}

public extension FolderVerdict {
    static func of(_ facts: FolderFacts) -> FolderVerdict {
        guard facts.isAbsolute else { return .refuse(.notAbsolute(facts.path)) }
        guard facts.exists else { return .refuse(.nothingThere(facts.path)) }
        guard facts.isDirectory else { return .refuse(.notADirectory(facts.path)) }
        if let problem = facts.gitProblem { return .refuse(.gitCannotRead(problem)) }

        if facts.isRepository {
            let root = facts.repositoryRoot ?? facts.path
            if FolderPath.isInside(root, of: facts.workspacesRoot) {
                return .refuse(.insideOurWorkspaces(root))
            }
            if FolderPath.sameFolder(root, facts.homeDirectory) { return .refuse(.homeDirectory) }
            if FolderPath.normalize(root) == "/" { return .refuse(.volumeRoot) }
            return .alreadyRepository(root: root)
        }

        if let enclosing = facts.enclosingRepository { return .refuse(.insideRepository(enclosing)) }

        let path = FolderPath.normalize(facts.path)
        if FolderPath.sameFolder(path, facts.homeDirectory) { return .refuse(.homeDirectory) }
        if FolderPath.isReserved(path, home: facts.homeDirectory) { return .refuse(.systemDirectory) }
        guard facts.isWritable else { return .refuse(.notWritable) }

        if facts.childRepositories.count >= FolderRefusal.projectContainerThreshold {
            return .refuse(.containerOfProjects(facts.childRepositories.sorted()))
        }
        return .offer
    }
}

public enum FolderPath {
    public static func normalize(_ path: String) -> String {
        let collapsed = (path as NSString).standardizingPath
        guard collapsed.count > 1, collapsed.hasSuffix("/") else { return collapsed }
        return String(collapsed.dropLast())
    }

    public static func resolved(_ path: String) -> String {
        URL(fileURLWithPath: normalize((path as NSString).expandingTildeInPath))
            .resolvingSymlinksInPath().path
    }

    public static func sameFolder(_ one: String, _ other: String) -> Bool {
        normalize(one) == normalize(other) || resolved(one) == resolved(other)
    }

    public static func isInside(_ path: String, of root: String) -> Bool {
        let one = resolved(path)
        let other = resolved(root)
        return one == other || one.hasPrefix(other + "/")
    }

    public static func isReserved(_ path: String, home: String) -> Bool {
        let normalized = normalize(path)

        if ownedTrees.contains(normalized) { return true }
        for tree in ownedTrees where normalized.hasPrefix(tree + "/") { return true }

        if containerRoots.contains(normalized) { return true }
        let parent = (normalized as NSString).deletingLastPathComponent
        if containerRoots.contains(parent) { return true }

        if bareRoots.contains(normalized) { return true }

        let normalizedHome = normalize(home)
        return reservedHomeChildren.contains { normalized == normalizedHome + "/" + $0 }
    }

    static let ownedTrees: Set<String> = [
        "/System", "/Library", "/bin", "/sbin", "/usr", "/etc", "/dev", "/cores",
    ]

    static let containerRoots: Set<String> = ["/Applications", "/Users", "/Volumes"]

    static let bareRoots: Set<String> = ["/", "/opt", "/private", "/tmp", "/var"]

    static let reservedHomeChildren: Set<String> = [
        "Applications", "Desktop", "Documents", "Downloads", "Library", "Movies", "Music",
        "Pictures", "Public",
    ]
}

public struct ExcludedPath: Sendable, Equatable, Identifiable {
    public enum Reason: Sendable, Equatable {
        case sensitive
        case nestedRepository
    }

    public var path: String
    public var reason: Reason

    public var id: String { path }

    public init(path: String, reason: Reason) {
        self.path = path
        self.reason = reason
    }

    public var gitignoreLine: String {
        var escaped = ""
        for character in path {
            if "*?[]\\ ".contains(character) { escaped.append("\\") }
            escaped.append(character)
        }
        return "/" + escaped + (reason == .nestedRepository ? "/" : "")
    }
}

public struct FolderContents: Sendable, Equatable {
    public var fileCount: Int
    public var byteSize: Int64
    public var truncated: Bool
    public var hasGitignore: Bool
    public var excluded: [ExcludedPath]
    public var oversizeFiles: [String]

    public init(
        fileCount: Int = 0,
        byteSize: Int64 = 0,
        truncated: Bool = false,
        hasGitignore: Bool = false,
        excluded: [ExcludedPath] = [],
        oversizeFiles: [String] = []
    ) {
        self.fileCount = fileCount
        self.byteSize = byteSize
        self.truncated = truncated
        self.hasGitignore = hasGitignore
        self.excluded = excluded
        self.oversizeFiles = oversizeFiles
    }

    public var isEmpty: Bool { fileCount == 0 && excluded.isEmpty }

    public var sensitiveFiles: [String] {
        excluded.filter { $0.reason == .sensitive }.map(\.path)
    }

    public var nestedRepositories: [String] {
        excluded.filter { $0.reason == .nestedRepository }.map(\.path)
    }

    public static let oversizeLimit: Int64 = 100 * 1_024 * 1_024
    public static let largeUploadLimit: Int64 = 100 * 1_024 * 1_024
    public static let manyFilesLimit = 5_000

    public var isLargeUpload: Bool {
        byteSize >= Self.largeUploadLimit || fileCount >= Self.manyFilesLimit || truncated
    }

    public var excludedSummary: String? {
        let secrets = sensitiveFiles.count
        let repositories = nestedRepositories.count
        var parts: [String] = []
        if secrets > 0 {
            parts.append(secrets == 1
                ? "1 file that looks like a credential"
                : "\(secrets) files that look like credentials")
        }
        if repositories > 0 {
            parts.append(repositories == 1
                ? "1 repository of its own"
                : "\(repositories) repositories of their own")
        }
        guard !parts.isEmpty else { return nil }
        return "Kept out and added to .gitignore: " + parts.joined(separator: ", ") + "."
    }

    public var summary: String {
        if isEmpty { return "Nothing yet, so the first commit will be empty." }
        let files = fileCount == 1 ? "1 file" : "\(fileCount.formatted()) files"
        let size = byteSize.formatted(.byteCount(style: .file))
        let prefix = truncated
            ? "More than \(files)"
            : (hasGitignore ? "At most \(files)" : "\(files.prefix(1).uppercased())\(files.dropFirst())")
        return "\(prefix), \(size)."
    }
}

public enum GitHubRepositoryName {
    public enum Problem: Sendable, Equatable {
        case empty
        case tooLong
        case invalidCharacters(String)
        case reserved
        case gitSuffix
    }

    public static let maxLength = 100

    public static func isAllowed(_ character: Character) -> Bool {
        character.isASCII && (character.isLetter || character.isNumber || "-_.".contains(character))
    }

    public static func problem(with name: String) -> Problem? {
        guard !name.isEmpty else { return .empty }
        guard name.count <= maxLength else { return .tooLong }
        if name == "." || name == ".." { return .reserved }
        if name.lowercased().hasSuffix(".git") { return .gitSuffix }

        var offenders = ""
        for character in name where !isAllowed(character) && !offenders.contains(character) {
            offenders.append(character)
        }
        return offenders.isEmpty ? nil : .invalidCharacters(offenders)
    }

    public static func isValid(_ name: String) -> Bool { problem(with: name) == nil }

    public static func suggestion(from folderName: String) -> String {
        var mapped = ""
        for character in folderName {
            mapped.append(isAllowed(character) ? character : "-")
        }
        while mapped.contains("--") {
            mapped = mapped.replacingOccurrences(of: "--", with: "-")
        }
        while let last = mapped.last, last == "-" || last == "." { mapped.removeLast() }
        while let first = mapped.first, first == "-" { mapped.removeFirst() }
        if mapped.lowercased().hasSuffix(".git") { mapped.removeLast(4) }
        if mapped.count > maxLength { mapped = String(mapped.prefix(maxLength)) }
        while let last = mapped.last, last == "-" || last == "." { mapped.removeLast() }
        return mapped.isEmpty ? "repository" : mapped
    }
}

public extension GitHubRepositoryName.Problem {
    var sentence: String {
        switch self {
        case .empty: "Give the repository a name."
        case .tooLong: "A repository name can be at most \(GitHubRepositoryName.maxLength) characters."
        case .invalidCharacters(let characters):
            "GitHub does not accept \(characters.map { "\($0)" }.joined(separator: " ")) in a "
                + "repository name. Letters, digits, hyphens, underscores and full stops only."
        case .reserved: "That name is not a name GitHub can use."
        case .gitSuffix: "A repository name cannot end in .git."
        }
    }
}

public enum NameAvailability: Sendable, Equatable {
    case idle
    case checking
    case available
    case taken
    case unknown(String)

    public var blocksCreation: Bool {
        self == .taken
    }

    public var sentence: String? {
        switch self {
        case .idle: nil
        case .checking: "Checking with GitHub."
        case .available: "Repository name is available."
        case .taken: "That name is already taken on GitHub."
        case .unknown(let why): why
        }
    }
}

public enum SensitiveFile {
    static let templateSuffixes = [
        ".example", ".sample", ".template", ".dist", ".defaults", ".test",
    ]

    static let exactNames: Set<String> = [
        ".netrc", ".npmrc", ".pypirc", ".htpasswd", ".pgpass", ".dockercfg",
        "auth.json", "credentials", "credentials.json", "secrets.json", "secrets.yml",
        "secrets.yaml", "id_rsa", "id_dsa", "id_ecdsa", "id_ed25519",
    ]

    static let extensions: Set<String> = [
        "pem", "key", "p12", "pfx", "keystore", "jks", "ppk", "asc", "kdbx",
    ]

    public static func matches(_ path: String) -> Bool {
        let name = (path as NSString).lastPathComponent
        let lowered = name.lowercased()

        for suffix in templateSuffixes where lowered.hasSuffix(suffix) { return false }
        if lowered.hasSuffix(".pub") { return false }

        if lowered == ".env" || lowered.hasPrefix(".env.") { return true }
        if exactNames.contains(lowered) { return true }
        if extensions.contains((lowered as NSString).pathExtension) { return true }

        if path.lowercased().hasSuffix(".aws/credentials") { return true }
        return false
    }
}
