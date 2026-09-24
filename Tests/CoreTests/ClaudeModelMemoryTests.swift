import Foundation
import Testing
@testable import Core

@Suite("Claude model memory", .tags(.agentProtocol))
struct ClaudeModelMemoryTests {
    @Test("a model written by hand is offered next to the four that ship")
    func remembersWhatWasWritten() {
        var memory = ClaudeModelMemory()
        let added = memory.remember("claude-opus-5-5")

        #expect(added)
        #expect(memory.models().map(\.id) == [
            "fable", "opus", "claude-opus-5-5", "sonnet", "haiku",
        ])
    }

    @Test("the new one carries a name rather than its id")
    func namesWhatWasWritten() {
        var memory = ClaudeModelMemory()
        memory.remember("claude-opus-5-5")

        #expect(memory.models().first { $0.id == "claude-opus-5-5" }?.displayName == "Opus 5.5")
    }

    @Test("one that already ships is not remembered twice")
    func ignoresABuiltIn() {
        var memory = ClaudeModelMemory()
        let added = memory.remember("opus")

        #expect(!added)
        #expect(memory.ids.isEmpty)
    }

    @Test("the same model written twice is kept once")
    func ignoresADuplicate() {
        var memory = ClaudeModelMemory()
        memory.remember("claude-opus-5-5")
        let again = memory.remember("claude-opus-5-5")

        #expect(!again)
        #expect(memory.ids == ["claude-opus-5-5"])
    }

    @Test("what was written survives being written down and read back")
    func survivesEncoding() {
        var memory = ClaudeModelMemory()
        memory.remember("claude-opus-5-5")
        memory.remember("claude-sonnet-5-2")

        #expect(ClaudeModelMemory.decode(memory.encoded) == memory)
    }

    @Test("nothing remembered stores nothing rather than an empty line")
    func storesNothingWhenEmpty() {
        #expect(ClaudeModelMemory().encoded == nil)
    }

    @Test("a stored value from an older build is tidied rather than trusted")
    func tidiesWhatWasStored() {
        let memory = ClaudeModelMemory.decode("\n claude-opus-5-5 \nopus\n\nclaude-opus-5-5\n")

        #expect(memory.ids == ["claude-opus-5-5"])
    }

    @Test("one written by mistake can be taken back out")
    func forgetsWhatWasWritten() {
        var memory = ClaudeModelMemory(ids: ["claude-opus-5-5"])
        let removed = memory.forget("claude-opus-5-5")

        #expect(removed)
        #expect(memory.models().map(\.id) == ClaudeModelCatalog.builtIn.map(\.id))
    }

    @Test("the model a session already runs is offered even when it was never written down")
    func offersTheRunningModel() {
        let ids = ClaudeModelMemory().models(including: "claude-opus-4-8").map(\.id)

        #expect(ids == ["fable", "opus", "claude-opus-4-8", "sonnet", "haiku"])
    }

    @Test("the four that ship are offered most expensive first")
    func ranksTheBuiltInList() {
        #expect(ClaudeModelCatalog.offered().map(\.id) == ["fable", "opus", "sonnet", "haiku"])
    }
}
