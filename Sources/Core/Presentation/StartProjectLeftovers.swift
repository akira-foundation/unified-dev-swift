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
        guard let half = half(of: stage) else { return nil }
        guard half == .cloning else {
            guard !namedFolder.isEmpty else { return nil }
            return StartProjectLeftovers(
                path: namedFolder,
                folderWasCreated: namedFolderWasCreated,
                cloned: false
            )
        }
        guard let clonedInto, !clonedInto.isEmpty else { return nil }
        return StartProjectLeftovers(path: clonedInto, folderWasCreated: true, cloned: true)
    }

    private static func half(of stage: StartProjectStage) -> StartProjectHalf? {
        switch stage {
        case .creating: .naming
        case .fetching: .cloning
        case .failed(let fault): fault.half
        case .landing, .naming, .cloning: nil
        }
    }
}
