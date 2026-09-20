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

    @Test("a card's row finds its own suggestion among the chat's, and nothing once it is gone")
    func cardFindsItsSuggestion() {
        let chat = SessionID("chat")
        let mine = WorkSuggestion(
            workspaceID: nil, sessionID: chat, title: "Keep the last row",
            why: "Because.", prompt: "Do it.", target: .sameProject
        )
        let other = WorkSuggestion(
            workspaceID: nil, sessionID: chat, title: "Something else",
            why: "Because.", prompt: "Do it.", target: .sameProject
        )
        let suggestions = TranscriptSuggestions([mine, other])

        #expect(suggestions.card(at: WorkSuggestionCardPayload.encode(mine.id)) == mine)
        #expect(suggestions.card(at: WorkSuggestionCardPayload.encode(other.id)) == other)
        #expect(suggestions.card(at: WorkSuggestionCardPayload.encode(WorkSuggestionID("gone"))) == nil)
        #expect(suggestions.card(at: Data("not json".utf8)) == nil)
        #expect(TranscriptSuggestions().card(at: WorkSuggestionCardPayload.encode(mine.id)) == nil)
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

    @Test("the card lands between the work_suggest call and its result, and the working after it folds on its own")
    func cardBetweenCallAndResult() {
        let facts = [
            TranscriptFold.Fact(seq: 0, kind: .user),
            TranscriptFold.Fact(seq: 1, kind: .assistantText),
            TranscriptFold.Fact(seq: 2, kind: .toolUse, toolUseID: "suggest"),
            TranscriptFold.Fact(seq: 3, kind: .suggestion),
            TranscriptFold.Fact(seq: 4, kind: .toolResult),
            TranscriptFold.Fact(seq: 5, kind: .toolUse),
            TranscriptFold.Fact(seq: 6, kind: .toolUse),
            TranscriptFold.Fact(seq: 7, kind: .assistantText),
            TranscriptFold.Fact(seq: 8, kind: .result),
        ]

        let folds = TranscriptFold.folds(in: facts)

        #expect(folds.all.map(\.span) == [5..<7])
        #expect(folds.all.allSatisfy { work in !work.span.contains(3) })
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

    @Test("every card a chat holds finds its suggestion in what the chat itself loads")
    func everyCardInAChatFindsItsSuggestion() async throws {
        let store = try makeTestStore("card-row-every")
        let chat = try await store.upsert(Session(workspaceID: nil, title: "Import"))
        _ = try await store.appendNext(sessionID: chat.id, kind: .user, payload: Data("{}".utf8))
        _ = try await store.appendNext(sessionID: chat.id, kind: .assistantText, payload: Data("{}".utf8))

        func add(_ title: String, limit: Int) async throws -> WorkSuggestion {
            let admission = try await store.addWorkSuggestion(
                WorkSuggestion(
                    workspaceID: nil, sessionID: chat.id, title: title,
                    why: "Because.", prompt: "Do it.", target: .remote("octo/parsekit")
                ),
                limit: limit
            )
            return try #require(admission.suggestion)
        }

        let dismissed = try await add("Dismissed", limit: .max)
        _ = try await store.dismissWorkSuggestion(id: dismissed.id)
        let withdrawn = try await add("Withdrawn", limit: .max)
        _ = try await store.withdrawWorkSuggestion(id: withdrawn.id, by: chat.id)
        for index in 1...WorkSuggestion.undecidedLimit {
            _ = try await add("Pending \(index)", limit: WorkSuggestion.undecidedLimit)
        }

        let suggestions = TranscriptSuggestions(try await store.workSuggestions(sessionID: chat.id))
        let cards = try await store.messages(sessionID: chat.id).filter { $0.kind == .suggestion }

        #expect(cards.count == WorkSuggestion.undecidedLimit + 2)
        #expect(cards.allSatisfy { suggestions.card(at: $0.payload) != nil })
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
