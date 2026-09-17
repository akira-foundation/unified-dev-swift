import Combine
import Foundation

public enum OpenWorkspaceNotification {
    private static let name = Notification.Name("unifieddevOpenWorkspace")

    public static func post(_ workspaceID: WorkspaceID, on centre: NotificationCenter = .default) {
        centre.post(name: name, object: workspaceID)
    }

    public static func publisher(
        on centre: NotificationCenter = .default
    ) -> AnyPublisher<WorkspaceID, Never> {
        centre.publisher(for: name)
            .compactMap { $0.object as? WorkspaceID }
            .eraseToAnyPublisher()
    }
}
