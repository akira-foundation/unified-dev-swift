import Foundation

public struct ClonedRepository: Sendable, Equatable {
    public var path: String
    public var branch: String?

    public init(path: String, branch: String? = nil) {
        self.path = path
        self.branch = branch
    }
}

public struct CloneFailure: Error, Sendable, Equatable {
    public var message: String
    public var folderWasCreated: Bool

    public init(message: String, folderWasCreated: Bool) {
        self.message = message
        self.folderWasCreated = folderWasCreated
    }

    public var title: String { "Could not clone the repository" }
}

public enum RepositoryCloner {
    public static func clone(
        _ remote: String,
        into destination: String
    ) async throws -> ClonedRepository {
        let existed = FileManager.default.fileExists(atPath: destination)
        do {
            try await Git.clone(remote, into: destination)
        } catch {
            if !existed { discard(destination) }
            throw CloneFailure(
                message: RepositoryStarter.sentence(from: error),
                folderWasCreated: false
            )
        }

        guard await Git.isRepository(destination) else {
            if !existed { discard(destination) }
            throw CloneFailure(
                message: "git clone finished and left no repository at \(destination).",
                folderWasCreated: false
            )
        }

        var branch: String?
        if let found = try? await Git.currentBranch(of: destination) { branch = found }
        return ClonedRepository(path: destination, branch: branch)
    }

    public static func discard(_ destination: String) {
        try? FileManager.default.removeItem(atPath: destination)
    }
}
