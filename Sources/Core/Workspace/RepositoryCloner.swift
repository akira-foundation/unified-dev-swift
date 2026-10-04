import Foundation

public struct ClonedRepository: Sendable, Equatable {
    public var path: String

    public init(path: String) {
        self.path = path
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
    public static let patience = Duration.seconds(30)

    public static let slowNotice = """
        git clone has not finished. A large repository takes a while, and it can also be waiting \
        on the network or on a key your agent has to approve. Stopping now leaves nothing behind.
        """

    public static func clone(
        _ remote: String,
        into destination: String
    ) async throws -> ClonedRepository {
        try claim(destination)
        do {
            try await Git.clone(remote, into: destination)
            guard await Git.isRepository(destination) else {
                throw CloneFailure(
                    message: "git clone finished and left no repository at \(destination).",
                    folderWasCreated: true
                )
            }
        } catch let failure as CloneFailure {
            discard(destination, folderWasCreated: true)
            throw CloneFailure(message: failure.message, folderWasCreated: false)
        } catch {
            discard(destination, folderWasCreated: true)
            throw CloneFailure(
                message: RepositoryStarter.sentence(from: error),
                folderWasCreated: false
            )
        }
        return ClonedRepository(path: destination)
    }

    public static func discard(_ destination: String, folderWasCreated: Bool) {
        guard folderWasCreated, !destination.isEmpty else { return }
        let folder = FolderPath.normalize((destination as NSString).expandingTildeInPath)
        guard folder.components(separatedBy: "/").count > 2 else { return }
        try? FileManager.default.removeItem(atPath: folder)
    }

    private static func claim(_ destination: String) throws {
        let parent = (destination as NSString).deletingLastPathComponent
        do {
            try FileManager.default.createDirectory(
                atPath: parent, withIntermediateDirectories: true
            )
            try FileManager.default.createDirectory(
                atPath: destination, withIntermediateDirectories: false
            )
        } catch {
            throw CloneFailure(
                message: CloneRefusal.occupied(destination).sentence,
                folderWasCreated: false
            )
        }
    }
}
