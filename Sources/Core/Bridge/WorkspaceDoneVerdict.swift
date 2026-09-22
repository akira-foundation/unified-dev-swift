import Foundation

public enum WorkspaceDoneVerdict: Sendable, Equatable {
    case ignore
    case discard
    case notify(CrewMessage)
}
