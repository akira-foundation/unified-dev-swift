import Foundation
import Testing
@testable import Core

@Suite("Braking workspace_say ping-pong")
struct WorkspaceSayThrottleTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func sent(
        _ text: String, minutesAgo: Double, state: WorkspaceMessage.State = .delivered
    ) -> WorkspaceMessage {
        WorkspaceMessage(
            stored: .new(),
            source: WorkspaceMessageEnd(workspaceID: WorkspaceID("a"), workspace: "a"),
            target: WorkspaceMessageEnd(workspaceID: WorkspaceID("b"), workspace: "b"),
            replySessionID: nil,
            text: text,
            deliveryID: nil,
            state: state,
            createdAt: now.addingTimeInterval(-minutesAgo * 60),
            deliveredAt: nil
        )
    }

    @Test("the limit is thirty messages in ten minutes")
    func numbers() {
        #expect(WorkspaceSayThrottle.limit == 30)
        #expect(WorkspaceSayThrottle.window == 10 * 60)
        #expect(WorkspaceSayThrottle.windowMinutes == 10)
    }

    @Test("the message after the limit inside the window is refused, and one outside it is not counted")
    func limit() {
        let spacing = WorkspaceSayThrottle.window / 60 / Double(WorkspaceSayThrottle.limit + 1)
        let full = (0..<WorkspaceSayThrottle.limit).map {
            sent("Update \($0)", minutesAgo: Double($0) * spacing)
        }
        #expect(
            WorkspaceSayThrottle.refusal(sending: "One more", to: "b", recent: full, now: now)
                == .tooMany(workspace: "b", count: WorkspaceSayThrottle.limit)
        )

        let oneIsOld = Array(full.dropLast()) + [sent("Old", minutesAgo: WorkspaceSayThrottle.window / 60 + 1)]
        #expect(WorkspaceSayThrottle.refusal(sending: "One more", to: "b", recent: oneIsOld, now: now) == nil)
    }

    @Test("a message sent exactly one window ago still counts, and one a second older does not")
    func windowEdge() {
        let edge = WorkspaceSayThrottle.window / 60
        let atEdge = [sent("Thanks, got it.", minutesAgo: edge)]
        let pastEdge = [sent("Thanks, got it.", minutesAgo: edge + 1.0 / 60)]

        #expect(
            WorkspaceSayThrottle.refusal(sending: "Thanks, got it.", to: "b", recent: atEdge, now: now)
                == .repeated(workspace: "b")
        )
        #expect(WorkspaceSayThrottle.refusal(sending: "Thanks, got it.", to: "b", recent: pastEdge, now: now) == nil)
    }

    @Test("one short of the limit still goes")
    func underTheLimit() {
        let spacing = WorkspaceSayThrottle.window / 60 / Double(WorkspaceSayThrottle.limit + 1)
        let almost = (0..<(WorkspaceSayThrottle.limit - 1)).map {
            sent("Update \($0)", minutesAgo: Double($0) * spacing)
        }
        #expect(WorkspaceSayThrottle.refusal(sending: "One more", to: "b", recent: almost, now: now) == nil)
    }

    @Test("the same words inside the window are refused, whitespace aside")
    func repeated() {
        let recent = [sent("Thanks, got it.", minutesAgo: 3)]

        #expect(
            WorkspaceSayThrottle.refusal(sending: "  Thanks, got it.\n", to: "b", recent: recent, now: now)
                == .repeated(workspace: "b")
        )
        let old = [sent("Thanks, got it.", minutesAgo: 11)]
        #expect(WorkspaceSayThrottle.refusal(sending: "Thanks, got it.", to: "b", recent: old, now: now) == nil)
    }

    @Test("cancelled messages are not counted by either rule")
    func cancelledDoNotCount() {
        let cancelled = (0..<40).map { _ in sent("Same", minutesAgo: 1, state: .cancelled) }

        #expect(WorkspaceSayThrottle.refusal(sending: "Same", to: "b", recent: cancelled, now: now) == nil)
    }

    @Test("the refusals tell the model not to retry, and name the workspace and the window")
    func sentences() {
        let repeated = WorkspaceSayTrouble.repeated(workspace: "release").sentence
        let tooMany = WorkspaceSayTrouble.tooMany(workspace: "release", count: 30).sentence

        #expect(repeated.contains("Do not retry"))
        #expect(repeated.contains("\"release\""))
        #expect(repeated.contains("10 minutes"))
        #expect(tooMany.contains("Do not retry"))
        #expect(tooMany.contains("30 messages"))
    }
}
