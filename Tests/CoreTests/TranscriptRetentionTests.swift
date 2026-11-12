import Testing
import Foundation
@testable import Core

@Suite("Which chats give their rows back once they leave the screen")
struct TranscriptRetentionTests {
    private func chat(
        _ name: String,
        in workspace: String? = "w",
        holdsRows: Bool = true,
        shown: Bool = false,
        busy: Bool = false,
        lastShown: Int
    ) -> TranscriptRetention.Chat {
        TranscriptRetention.Chat(
            session: SessionID(name),
            workspace: workspace.map { WorkspaceID($0) },
            holdsRows: holdsRows,
            isShown: shown,
            isBusy: busy,
            lastShown: lastShown
        )
    }

    private func idle(_ count: Int) -> [TranscriptRetention.Chat] {
        (1...count).map { chat("c\($0)", lastShown: $0) }
    }

    @Test("idle chats within the bound keep their rows")
    func withinTheBound() {
        #expect(TranscriptRetention.chatsToRelease(idle(TranscriptRetention.keptIdleChats)).isEmpty)
    }

    @Test("past the bound, the chats shown longest ago give their rows back")
    func oldestGoFirst() {
        let released = TranscriptRetention.chatsToRelease(idle(TranscriptRetention.keptIdleChats + 3))
        #expect(Set(released) == [SessionID("c1"), SessionID("c2"), SessionID("c3")])
    }

    @Test("a chat on screen is never released, however long ago it was first shown")
    func shownIsKept() {
        var chats = idle(TranscriptRetention.keptIdleChats + 3)
        chats[0].isShown = true
        let released = TranscriptRetention.chatsToRelease(chats)
        #expect(!released.contains(SessionID("c1")))
        #expect(released.count == 2)
    }

    @Test("a running, sending or delivering chat is never released and takes no place in the bound")
    func busyIsKept() {
        var chats = idle(TranscriptRetention.keptIdleChats + 2)
        chats[0].isBusy = true
        chats[1].isBusy = true
        #expect(TranscriptRetention.chatsToRelease(chats).isEmpty)
    }

    @Test("a chat that holds no rows is not asked to give any back")
    func emptyIsSkipped() {
        var chats = idle(TranscriptRetention.keptIdleChats + 1)
        chats[0].holdsRows = false
        #expect(TranscriptRetention.chatsToRelease(chats).isEmpty)
    }

    @Test("a workspace past the bound is released unless it is selected or holds a busy or shown chat")
    func workspaces() {
        let ids = (1...7).map { WorkspaceID("w\($0)") }
        var chats = ids.enumerated().map { index, id in
            chat("c\(index)", in: id.rawValue, lastShown: index + 1)
        }
        chats[0].isBusy = true
        chats[1].isShown = true
        let released = TranscriptRetention.workspacesToRelease(ids, chats: chats, selected: WorkspaceID("w3"))
        #expect(Set(released) == [WorkspaceID("w4")])
    }

    @Test("a workspace whose chats were never shown is released before one that was")
    func neverShownGoesFirst() {
        let ids = (1...5).map { WorkspaceID("w\($0)") }
        let chats = [chat("a", in: "w5", lastShown: 9), chat("b", in: "w4", lastShown: 8), chat("c", in: "w3", lastShown: 7)]
        let released = TranscriptRetention.workspacesToRelease(ids, chats: chats, selected: nil)
        #expect(Set(released) == [WorkspaceID("w1"), WorkspaceID("w2")])
    }
}
