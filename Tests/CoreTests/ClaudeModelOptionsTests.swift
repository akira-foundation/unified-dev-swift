import Foundation
import Testing
@testable import Core

@Suite("The Claude models the CLI knows about", .tags(.agentProtocol))
struct ClaudeModelOptionsTests {
    static let measured = Data("""
    {"numStartups": 41,
     "additionalModelOptionsCache": [
       {"value": "claude-fable-5-1[1m]", "label": "Fable",
        "description": "Fable 5.1 \\u00b7 Most capable for your hardest and longest-running tasks"},
       {"value": "cc-update-required-1", "label": "Opus 5.5 (disabled)",
        "description": "Update to 2.1.280+ to use Opus 5.5", "disabled": true}
     ]}
    """.utf8)

    @Test("the models the CLI's own config carries are read from it")
    func readsWhatTheCLIWasTold() {
        let models = ClaudeModelOptions.decode(Self.measured)

        #expect(models.map(\.id) == ["claude-fable-5-1[1m]", "cc-update-required-1"])
    }

    @Test("a real id is named the way every other model here is named")
    func namesARealID() {
        let fable = ClaudeModelOptions.decode(Self.measured).first { $0.id.hasPrefix("claude-") }

        #expect(fable?.displayName == "Fable 5.1 (1m)")
        #expect(fable?.unavailable == nil)
    }

    @Test("one the account cannot use yet keeps the server's name and says why")
    func explainsOneItCannotUse() {
        let blocked = ClaudeModelOptions.decode(Self.measured).first { $0.unavailable != nil }

        #expect(blocked?.displayName == "Opus 5.5")
        #expect(blocked?.unavailable == "Update to 2.1.280+ to use Opus 5.5")
    }

    @Test("a config with nothing to say leaves the built in list alone", arguments: [
        Data(), Data("{}".utf8), Data("not json".utf8),
        Data(#"{"additionalModelOptionsCache": []}"#.utf8),
    ])
    func readsNothingFromAnEmptyConfig(json: Data) {
        #expect(ClaudeModelOptions.decode(json).isEmpty)
        #expect(ClaudeModelCatalog.offered(read: ClaudeModelOptions.decode(json)).map(\.id)
            == ClaudeModelCatalog.builtIn.map(\.id))
    }

    @Test("an entry with no id of its own is skipped rather than offered blank")
    func skipsAnEntryWithNoID() {
        let json = Data(#"{"additionalModelOptionsCache":[{"label":"Nameless"},{"value":"  "}]}"#.utf8)

        #expect(ClaudeModelOptions.decode(json).isEmpty)
    }

    @Test("one the CLI blocked without saying why still says something")
    func explainsABlockWithNoReason() {
        let json = Data(#"{"additionalModelOptionsCache":[{"value":"x-1","disabled":true}]}"#.utf8)

        #expect(ClaudeModelOptions.decode(json).first?.unavailable == "Not available on this account.")
    }

    @Test("what the CLI knows is offered beside the four that ship, in rank order")
    func mergesWithTheBuiltInList() {
        let offered = ClaudeModelCatalog.offered(read: ClaudeModelOptions.decode(Self.measured))

        #expect(offered.map(\.id) == [
            "fable", "claude-fable-5-1[1m]", "opus", "sonnet", "haiku", "cc-update-required-1",
        ])
    }

    @Test("the four that ship are named after the alias, never after a version of it")
    func namesTheAliasesWithoutAVersion() {
        #expect(ClaudeModelCatalog.builtIn.map(\.displayName)
            == ["Fable", "Opus", "Sonnet", "Haiku"])
    }

    @Test("the model a session runs is offered even when the CLI has never heard of it")
    func keepsTheRunningModel() {
        let offered = ClaudeModelCatalog.offered(including: "claude-opus-4-8")

        #expect(offered.map(\.id) == ["fable", "opus", "claude-opus-4-8", "sonnet", "haiku"])
        #expect(offered.first { $0.id == "claude-opus-4-8" }?.displayName == "Opus 4.8")
    }

    @Test("reading it twice reads the file once, because it is cached like the other two")
    func cachesTheRead() async throws {
        let reads = Counter()
        let source = ClaudeModelSource(read: { await reads.bump(); return Self.measured })

        _ = try await source.models()
        _ = try await source.models()

        #expect(await reads.count == 1)
    }

    @Test("asking again after a refresh reads the file again")
    func readsAgainAfterInvalidating() async throws {
        let reads = Counter()
        let source = ClaudeModelSource(read: { await reads.bump(); return Self.measured })

        _ = try await source.models()
        await source.invalidate()
        _ = try await source.models()

        #expect(await reads.count == 2)
    }

    actor Counter {
        private(set) var count = 0
        func bump() { count += 1 }
    }
}
