import Foundation
import Testing
@testable import Core

@Suite("A suggestion's card as a row of the transcript")
struct WorkSuggestionRowTests {
    @Test("the card's row names the suggestion it draws, and nothing else")
    func payloadRoundTrip() {
        let id = WorkSuggestionID("s-card")

        #expect(WorkSuggestionCardPayload.decode(WorkSuggestionCardPayload.encode(id)) == id)
        #expect(WorkSuggestionCardPayload.decode(Data(#"{"suggestion_id":"s-card"}"#.utf8)) == id)
        #expect(WorkSuggestionCardPayload.decode(Data("not json".utf8)) == nil)
    }

    @Test("a card is drawn like a notice, fades in, is searched as a suggestion and keeps no words of its own")
    func kindDecisions() {
        #expect(TranscriptRowShape.of(kind: .suggestion) == .notice)
        #expect(TranscriptMotion.fadesOnArrival(.suggestion))
        #expect(TranscriptSearch.label(for: .suggestion) == "Suggestion")
        #expect(!TranscriptSearchText.isIndexed(.suggestion))
    }

    @Test("a card splits the working around it, and is never folded away")
    func cardIsABoundary() {
        let tool = { (seq: Int) in TranscriptFold.Fact(seq: seq, kind: .toolUse) }
        let facts = [TranscriptFold.Fact(seq: 0, kind: .user)]
            + (1..<4).map(tool) + [TranscriptFold.Fact(seq: 4, kind: .suggestion)]
            + (5..<8).map(tool)
            + [TranscriptFold.Fact(seq: 8, kind: .assistantText), TranscriptFold.Fact(seq: 9, kind: .result)]

        let folds = TranscriptFold.folds(in: facts)

        #expect(folds.all.map(\.span) == [1..<4, 5..<8])
        #expect(folds.all.allSatisfy { work in !work.rows.map(\.seq).contains(4) })
    }
}

@Suite("A suggestion's card in the store", .tags(.persistence), .scratchDirectory)
struct WorkSuggestionCardRowStoreTests {
    @Test("a suggestion puts its card in the chat right after what is already there, and remembers where")
    func cardFollowsTheMessages() async throws {
        let store = try makeTestStore("card-row")
        let repo = try await store.upsert(Repo(name: "lantern", path: "/tmp/lantern", defaultBranch: "main"))
        let workspace = try await store.upsert(Workspace(
            repoID: repo.id, name: "Importer", branch: "importer", path: "/tmp/lantern-importer", baseBranch: "main"
        ))
        let chat = try await store.upsert(Session(workspaceID: workspace.id, title: "Import"))
        _ = try await store.appendNext(sessionID: chat.id, kind: .user, payload: Data("{}".utf8))
        _ = try await store.appendNext(sessionID: chat.id, kind: .assistantText, payload: Data("{}".utf8))

        let admission = try await store.addWorkSuggestion(WorkSuggestion(
            workspaceID: workspace.id, sessionID: chat.id, title: "Keep the last row",
            why: "Because.", prompt: "Do it.", target: .sameProject
        ))
        let suggestion = try #require(admission.suggestion)
        let messages = try await store.messages(sessionID: chat.id)

        #expect(messages.map(\.kind) == [.user, .assistantText, .suggestion])
        #expect(WorkSuggestionCardPayload.decode(messages[2].payload) == suggestion.id)
        #expect(suggestion.anchorSeq == messages[2].seq)
    }

    @Test("a refused sixth leaves no card behind")
    func refusedLeavesNoCard() async throws {
        let store = try makeTestStore("card-row-full")
        let chat = try await store.upsert(Session(workspaceID: nil, title: "Ask"))
        for index in 1...WorkSuggestion.undecidedLimit + 1 {
            _ = try await store.addWorkSuggestion(WorkSuggestion(
                workspaceID: nil, sessionID: chat.id, title: "Work \(index)",
                why: "Because.", prompt: "Do it.", target: .remote("octo/parsekit")
            ))
        }

        let messages = try await store.messages(sessionID: chat.id)

        #expect(messages.count == WorkSuggestion.undecidedLimit)
    }
}
