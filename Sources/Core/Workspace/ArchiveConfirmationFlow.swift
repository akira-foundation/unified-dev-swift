import Foundation

public enum ArchiveConfirmationFlow {
    public enum Update: Sendable {
        case offer(ArchiveRequest)
        case replace(ArchiveRequest)
        case withdraw(WorkspaceID)

        public var request: ArchiveRequest? {
            switch self {
            case .offer(let request), .replace(let request): request
            case .withdraw: nil
            }
        }

        var workspaceID: WorkspaceID {
            switch self {
            case .offer(let request), .replace(let request): request.id
            case .withdraw(let id): id
            }
        }
    }

    public static func shows(_ update: Update, while shown: ArchiveRequest?) -> ArchiveRequest? {
        switch update {
        case .offer(let request): request
        case .replace, .withdraw: shown?.id == update.workspaceID ? update.request : shown
        }
    }
}
