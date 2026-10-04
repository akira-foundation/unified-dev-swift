import Foundation

public enum StartProjectHalf: Sendable, Equatable {
    case naming
    case cloning

    public var stage: StartProjectStage {
        switch self {
        case .naming: .naming
        case .cloning: .cloning
        }
    }
}

public struct StartProjectFault: Sendable, Equatable {
    public var title: String
    public var message: String
    public var folderWasCreated: Bool
    public var half: StartProjectHalf

    public init(
        title: String,
        message: String,
        folderWasCreated: Bool,
        half: StartProjectHalf
    ) {
        self.title = title
        self.message = message
        self.folderWasCreated = folderWasCreated
        self.half = half
    }

    public init(_ failure: NewProjectFailure) {
        self.init(
            title: failure.title,
            message: failure.message,
            folderWasCreated: failure.folderWasCreated,
            half: .naming
        )
    }

    public init(_ failure: CloneFailure) {
        self.init(
            title: failure.title,
            message: failure.message,
            folderWasCreated: failure.folderWasCreated,
            half: .cloning
        )
    }
}

public enum StartProjectStage: Sendable, Equatable {
    case landing
    case naming
    case cloning
    case creating(RepositoryStartStep)
    case fetching
    case failed(StartProjectFault)
}

public extension StartProjectStage {
    var isRunning: Bool {
        switch self {
        case .creating, .fetching: true
        case .landing, .naming, .cloning, .failed: false
        }
    }

    var takesTheWholeCard: Bool {
        if case .landing = self { return true }
        return false
    }

    var discardsOnLeaving: Bool { isRunning }

    var leaving: StartProjectStage? {
        switch self {
        case .landing, .creating, .fetching: nil
        case .naming, .cloning: .landing
        case .failed(let fault): fault.half.stage
        }
    }

    var title: String {
        switch self {
        case .landing: "Start a project"
        case .naming: "New project"
        case .cloning: "Clone a repository"
        case .creating: "Setting it up"
        case .fetching: "Cloning"
        case .failed(let fault): fault.title
        }
    }

    static func after(_ failure: NewProjectFailure) -> StartProjectStage {
        .failed(StartProjectFault(failure))
    }

    static func after(_ failure: CloneFailure) -> StartProjectStage {
        .failed(StartProjectFault(failure))
    }
}
