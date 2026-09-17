import Combine
import Foundation
import Testing
@testable import Core

@Suite("Open workspace notification")
struct OpenWorkspaceNotificationTests {
    @Test("an id posted is the id delivered")
    func roundTrips() {
        let centre = NotificationCenter()
        let received = Received()

        let subscription = OpenWorkspaceNotification.publisher(on: centre)
            .sink { received.ids.append($0) }
        OpenWorkspaceNotification.post(WorkspaceID("w1"), on: centre)
        OpenWorkspaceNotification.post(WorkspaceID("w2"), on: centre)
        subscription.cancel()
        OpenWorkspaceNotification.post(WorkspaceID("w3"), on: centre)

        #expect(received.ids == [WorkspaceID("w1"), WorkspaceID("w2")])
    }

    @Test("a bare string posted down the same channel is not mistaken for an id")
    func aStringIsNotAnIdentifier() {
        let centre = NotificationCenter()
        let received = Received()

        let subscription = OpenWorkspaceNotification.publisher(on: centre)
            .sink { received.ids.append($0) }
        centre.post(name: Notification.Name("unifieddevOpenWorkspace"), object: "w1")
        OpenWorkspaceNotification.post(WorkspaceID("w2"), on: centre)
        subscription.cancel()

        #expect(received.ids == [WorkspaceID("w2")])
    }

    private final class Received {
        var ids: [WorkspaceID] = []
    }
}
