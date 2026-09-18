import Foundation

public enum WorkspaceDraftWrite: Equatable, Sendable {
    case insert
    case update
    case delete
    case nothing

    public static func decide(hasContent: Bool, isStored: Bool) -> Self {
        switch (hasContent, isStored) {
        case (true, false): .insert
        case (true, true): .update
        case (false, true): .delete
        case (false, false): .nothing
        }
    }
}
