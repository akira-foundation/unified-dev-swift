import Foundation

public struct StartProjectLeftovers: Sendable, Equatable {
    public var path: String
    public var folderWasCreated: Bool
    public var cloned: Bool

    public init(path: String, folderWasCreated: Bool, cloned: Bool) {
        self.path = path
        self.folderWasCreated = folderWasCreated
        self.cloned = cloned
    }
}

public extension StartProjectLeftovers {
    static func of(
        _ stage: StartProjectStage,
        namedFolder: String,
        namedFolderWasCreated: Bool,
        clonedInto: String?
    ) -> StartProjectLeftovers? {
        switch stage {
        case .landing, .naming, .cloning:
            nil

        case .creating:
            named(namedFolder, wasCreated: namedFolderWasCreated)

        case .fetching:
            cloned(clonedInto, wasCreated: true)

        case .failed(let fault):
            switch fault.half {
            case .naming: named(namedFolder, wasCreated: fault.folderWasCreated)
            case .cloning: cloned(clonedInto, wasCreated: fault.folderWasCreated)
            }
        }
    }

    func discard() async {
        guard !path.isEmpty else { return }
        guard cloned else {
            await NewProjectStarter.discard(at: path, folderWasCreated: folderWasCreated)
            return
        }
        RepositoryCloner.discard(path, folderWasCreated: folderWasCreated)
    }

    private static func named(_ path: String, wasCreated: Bool) -> StartProjectLeftovers? {
        guard !path.isEmpty else { return nil }
        return StartProjectLeftovers(path: path, folderWasCreated: wasCreated, cloned: false)
    }

    private static func cloned(_ path: String?, wasCreated: Bool) -> StartProjectLeftovers? {
        guard wasCreated, let path, !path.isEmpty else { return nil }
        return StartProjectLeftovers(path: path, folderWasCreated: true, cloned: true)
    }
}
