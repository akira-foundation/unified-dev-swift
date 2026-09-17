import Foundation

public enum NewProjectStarter {
    public static func inspect(
        name: String,
        location: String,
        home: String = FileManager.default.homeDirectoryForCurrentUser.path,
        workspacesRoot: String = WorkspaceManager.workspacesRoot.path
    ) -> NewProjectFacts {
        var facts = NewProjectFacts(
            name: name,
            location: location,
            homeDirectory: home,
            workspacesRoot: workspacesRoot
        )
        guard let path = NewProjectPlan.target(name: name, location: location, home: home) else {
            return facts
        }

        let manager = FileManager.default
        facts.path = path
        let parent = (path as NSString).deletingLastPathComponent

        var isDirectory: ObjCBool = false
        facts.locationExists = manager.fileExists(atPath: parent, isDirectory: &isDirectory)
            && isDirectory.boolValue

        isDirectory = false
        facts.targetExists = manager.fileExists(atPath: path, isDirectory: &isDirectory)
        facts.targetIsDirectory = facts.targetExists && isDirectory.boolValue
        if facts.targetIsDirectory {
            facts.targetIsRepository = manager.fileExists(
                atPath: (path as NSString).appendingPathComponent(".git")
            )
            facts.targetIsEmpty = isEmpty(path)
            facts.isTargetWritable = manager.isWritableFile(atPath: path)
            if !facts.targetIsRepository, !facts.targetIsEmpty {
                facts.childRepositories = RepositoryStarter.childRepositories(of: path)
            }
        }

        facts.enclosingRepository = Git.enclosingRepositoryRoot(of: path)
        let ancestor = nearestExistingAncestor(of: path)
        facts.nearestExistingAncestor = ancestor
        facts.isAncestorWritable = manager.isWritableFile(atPath: ancestor)
        return facts
    }

    public static func inspect(
        typed: String,
        defaultLocation: String,
        home: String = FileManager.default.homeDirectoryForCurrentUser.path,
        workspacesRoot: String = WorkspaceManager.workspacesRoot.path
    ) -> NewProjectFacts {
        let target = ProjectTarget.resolve(typed, defaultLocation: defaultLocation, home: home)
        return inspect(
            name: target.name,
            location: target.location,
            home: home,
            workspacesRoot: workspacesRoot
        )
    }

    static func isEmpty(_ path: String) -> Bool {
        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: path) else {
            return false
        }
        return entries.allSatisfy { $0 == ".DS_Store" }
    }

    static func nearestExistingAncestor(of path: String) -> String {
        var current = (FolderPath.normalize(path) as NSString).deletingLastPathComponent
        while current.count > 1, !FileManager.default.fileExists(atPath: current) {
            current = (current as NSString).deletingLastPathComponent
        }
        return current.isEmpty ? "/" : current
    }

    public static func repositoryProblem(at path: String) async -> GitRepositoryProblem? {
        switch await Git.repositoryAnswer(path) {
        case .repository: nil
        case .notARepository:
            .failed(detail: "there is a .git here, but git does not recognise it as a repository")
        case .problem(let problem): problem
        }
    }

    public static func plannedBranch(
        home: String = FileManager.default.homeDirectoryForCurrentUser.path
    ) async -> String {
        let configured = try? await Git.run(["config", "--get", "init.defaultBranch"], in: home)
        guard let configured, configured.ok else { return "main" }
        let preference = configured.trimmed
        return preference.isEmpty ? "main" : preference
    }

    public static func create(
        at path: String,
        progress: @Sendable @MainActor (RepositoryStartStep) -> Void = { _ in }
    ) async throws -> NewProjectCreation {
        let folder = FolderPath.normalize((path as NSString).expandingTildeInPath)
        var created = false

        if !FileManager.default.fileExists(atPath: folder) {
            do {
                try FileManager.default.createDirectory(
                    atPath: folder, withIntermediateDirectories: true
                )
                created = true
            } catch {
                throw NewProjectFailure(
                    title: "Could not create the folder",
                    message: RepositoryStarter.sentence(from: error),
                    folderWasCreated: false
                )
            }
        }

        do {
            let outcome = try await RepositoryStarter.start(
                at: folder, destination: .local, progress: progress
            )
            return NewProjectCreation(
                path: folder, branch: outcome.branch, folderWasCreated: created
            )
        } catch let failure as RepositoryStartFailure {
            throw NewProjectFailure(
                title: failure.title, message: failure.message, folderWasCreated: created
            )
        } catch {
            throw NewProjectFailure(
                title: "Could not create the repository",
                message: RepositoryStarter.sentence(from: error),
                folderWasCreated: created
            )
        }
    }

    @discardableResult
    public static func discard(
        at path: String, folderWasCreated: Bool
    ) async -> NewProjectAbandonment {
        let folder = FolderPath.normalize((path as NSString).expandingTildeInPath)
        let repository = await RepositoryStarter.abandon(at: folder)

        guard folderWasCreated, repository != .projectKept, isEmpty(folder) else {
            return NewProjectAbandonment(repository: repository, folderRemoved: false)
        }
        let removed = (try? FileManager.default.removeItem(atPath: folder)) != nil
        return NewProjectAbandonment(repository: repository, folderRemoved: removed)
    }
}

public struct NewProjectCreation: Sendable, Equatable {
    public var path: String
    public var branch: String
    public var folderWasCreated: Bool

    public init(path: String, branch: String, folderWasCreated: Bool) {
        self.path = path
        self.branch = branch
        self.folderWasCreated = folderWasCreated
    }
}

public struct NewProjectFailure: Error, Sendable, Equatable {
    public var title: String
    public var message: String
    public var folderWasCreated: Bool

    public init(title: String, message: String, folderWasCreated: Bool) {
        self.title = title
        self.message = message
        self.folderWasCreated = folderWasCreated
    }
}

public struct NewProjectAbandonment: Sendable, Equatable {
    public var repository: RepositoryStartAbandonment
    public var folderRemoved: Bool

    public init(repository: RepositoryStartAbandonment, folderRemoved: Bool) {
        self.repository = repository
        self.folderRemoved = folderRemoved
    }

    public var isUsableProject: Bool { repository.isUsableProject }

    public var state: String {
        if folderRemoved {
            return "Unified Dev removed the folder it had just made, so nothing is left on disk."
        }
        return repository.state
    }
}
