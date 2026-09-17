import Testing
import Foundation
@testable import Core

@Suite("A model id that names its own backend")
struct ModelIdentifierTests {
    static let codexModels = [
        CodexModel(
            id: "gpt-5.6-sol",
            displayName: "GPT-5.6 Sol",
            supportedEfforts: ["none", "low", "medium", "high", "xhigh", "ultra"]
                .map { CodexReasoningEffort(id: $0) },
            defaultEffort: "low"
        ),
        CodexModel(
            id: "gpt-5.5",
            displayName: "GPT-5.5",
            supportedEfforts: ["low", "medium", "high", "xhigh"]
                .map { CodexReasoningEffort(id: $0) },
            defaultEffort: "medium"
        ),
    ]

    @Test("the row the user photographed is what this id renders as")
    func theReportedRow() {
        #expect(ModelLabel.readable("codex:gpt-5.6-sol") == "Codex:gpt 5.6 Sol")
    }

    @Test("the backend in front of the id is read rather than stored")
    func theNamespaceIsRead() {
        let resolved = ModelIdentifier.resolve("codex:gpt-5.6-sol", models: [.codex: Self.codexModels.map(\.agentModel)])
        #expect(resolved.model == "gpt-5.6-sol")
        #expect(resolved.kind == .codex)
        #expect(resolved.namesBackend)
    }

    @Test("it needs no fetched list")
    func theNamespaceNeedsNoList() {
        let resolved = ModelIdentifier.resolve("codex:gpt-5.6-sol")
        #expect(resolved.model == "gpt-5.6-sol")
        #expect(resolved.kind == .codex)
    }

    @Test("a backend is named by its key, its name or its command", arguments: [
        ("codex:gpt-5.5", AgentKind.codex, "gpt-5.5"),
        ("Codex: gpt-5.5", AgentKind.codex, "gpt-5.5"),
        ("claudeCode:opus", AgentKind.claudeCode, "opus"),
        ("claude-code:opus", AgentKind.claudeCode, "opus"),
        ("Claude Code:opus", AgentKind.claudeCode, "opus"),
        ("claude:opus", AgentKind.claudeCode, "opus"),
    ])
    func theSpellings(raw: String, kind: AgentKind, model: String) {
        let resolved = ModelIdentifier.resolve(raw, models: [.codex: Self.codexModels.map(\.agentModel)])
        #expect(resolved.kind == kind)
        #expect(resolved.model == model)
        #expect(resolved.namesBackend)
    }

    @Test("a rendered label is read back as the id it was drawn from", arguments: [
        "Codex:gpt 5.6 Sol",
        "codex:GPT-5.6 Sol",
        "GPT-5.6 Sol",
        "gpt 5.6 sol",
    ])
    func aLabelIsReadBack(raw: String) {
        let resolved = ModelIdentifier.resolve(raw, models: [.codex: Self.codexModels.map(\.agentModel)])
        #expect(resolved.model == "gpt-5.6-sol")
        #expect(resolved.kind == .codex)
    }

    @Test("a label with no list keeps its backend and waits")
    func aLabelWithNoList() {
        let resolved = ModelIdentifier.resolve("Codex:gpt 5.6 Sol")
        #expect(resolved.kind == .codex)
        #expect(resolved.model == "gpt 5.6 Sol")
    }

    @Test("real ids pass through untouched", arguments: [
        "opus", "sonnet", "fable", "haiku",
        "claude-opus-5", "claude-opus-5[1m]", "opus-5-1m", "claude-haiku-4-5-20251001",
        "gpt-5.6-sol", "gpt-5.5", "gpt-5.3-codex-spark",
        "internal-preview-3",
    ])
    func realIDsSurvive(id: String) {
        #expect(ModelIdentifier.resolve(id, models: [.codex: Self.codexModels.map(\.agentModel)]).model == id)
        #expect(!ModelIdentifier.resolve(id, models: [.codex: Self.codexModels.map(\.agentModel)]).namesBackend)
    }

    @Test("a namespace that is not a backend is left alone")
    func anUnknownNamespaceSurvives() {
        let resolved = ModelIdentifier.resolve("openrouter:openai/gpt-4", models: [.codex: Self.codexModels.map(\.agentModel)])
        #expect(resolved.model == "openrouter:openai/gpt-4")
        #expect(resolved.kind == nil)
        #expect(!resolved.namesBackend)
    }

    @Test("a bare backend name is not a model")
    func aBareBackendName() {
        #expect(ModelIdentifier.resolve("codex:").model == "codex:")
        #expect(ModelIdentifier.resolve("").model == "")
    }

    @Test("a grok-prefixed id names Grok without a fetch")
    func grokPrefixIsItsOwnNamespace() {
        let resolved = ModelIdentifier.resolve("grok-4.6")
        #expect(resolved.model == "grok-4.6")
        #expect(resolved.kind == .grok)
        #expect(!resolved.namesBackend)

        let named = ModelIdentifier.resolve("grok:grok-4.6")
        #expect(named.model == "grok-4.6")
        #expect(named.kind == .grok)
        #expect(named.namesBackend)
    }

    @Test("a chat that has not spoken is put on the backend its model names")
    func aFreshChatIsMoved() throws {
        let repair = try #require(ModelIdentifier.correction(
            model: "codex:gpt-5.6-sol",
            on: .claudeCode,
            hasSpoken: false,
            models: [.codex: Self.codexModels.map(\.agentModel)]
        ))
        #expect(repair.model == "gpt-5.6-sol")
        #expect(repair.kind == .codex)
    }

    @Test("a chat that has spoken keeps its backend and still gets a usable id")
    func aSpokenChatKeepsItsBackend() throws {
        let repair = try #require(ModelIdentifier.correction(
            model: "codex:gpt-5.6-sol",
            on: .claudeCode,
            hasSpoken: true,
            models: [.codex: Self.codexModels.map(\.agentModel)]
        ))
        #expect(repair.model == "gpt-5.6-sol")
        #expect(repair.kind == .claudeCode)
    }

    @Test("a chat that is already right is left alone", arguments: [
        "opus", "claude-opus-5[1m]", "gpt-5.6-sol", "internal-preview-3",
    ])
    func nothingToCorrect(model: String) {
        #expect(ModelIdentifier.correction(
            model: model,
            on: .claudeCode,
            hasSpoken: false,
            models: [.codex: Self.codexModels.map(\.agentModel)]
        ) == nil)
    }

    @Test("the menu and the defaults agree about the id after it is read")
    func theMenuAgrees() {
        let stuck = "codex:gpt-5.6-sol"
        #expect(DefaultBackend.kind(
            ofModel: stuck, running: .claudeCode, models: [.codex: Self.codexModels.map(\.agentModel)]
        ) == .codex)

        let repaired = ModelIdentifier.resolve(stuck, models: [.codex: Self.codexModels.map(\.agentModel)]).model
        #expect(DefaultBackend.kind(
            ofModel: repaired, running: .claudeCode, models: [.codex: Self.codexModels.map(\.agentModel)]
        ) == .codex)
    }
}
