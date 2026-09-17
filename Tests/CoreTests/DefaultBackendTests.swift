import Testing
import Foundation
@testable import Core

@Suite("The backend a new chat opens on", .scratchDirectory)
struct DefaultBackendTests {
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

    @Test("a model stored before the key existed still opens Claude Code")
    func aStoredModelWithNoBackendIsClaudeCode() async throws {
        let store = try makeTestStore("default-backend-legacy")
        try await store.setSetting(AppDefaults.Key.model, "sonnet")
        try await store.setSetting(AppDefaults.Key.effort, "medium")

        let defaults = await AppDefaults.load(from: store)
        #expect(defaults.backend == .claudeCode)

        let resolved = ComposerDefaults.resolve(repo: RepoSettings(), app: defaults)
        #expect(resolved.model == "sonnet")
        #expect(resolved.backend == .claudeCode)
    }

    @Test("a Codex model chosen in Settings opens Codex with nothing fetched")
    func aStoredCodexModelOpensCodex() async throws {
        let store = try makeTestStore("default-backend-codex")
        await AppDefaults(model: "gpt-5.6-sol", effort: "high", backend: .codex).save(to: store)

        let defaults = await AppDefaults.load(from: store)
        #expect(defaults.backend == .codex)

        let resolved = ComposerDefaults.resolve(repo: RepoSettings(), app: defaults)
        #expect(resolved.model == "gpt-5.6-sol")
        #expect(resolved.backend == .codex)
    }

    @Test("the review model carries its own backend and inherits the other when it has none")
    func theReviewRowHasABackendOfItsOwn() async throws {
        let store = try makeTestStore("default-backend-review")
        try await store.setSetting(AppDefaults.Key.backend, AgentKind.codex.rawValue)

        var defaults = await AppDefaults.load(from: store)
        #expect(defaults.reviewBackend == .codex)

        defaults.reviewBackend = .claudeCode
        defaults.reviewModel = "opus"
        await defaults.save(to: store)
        #expect(await AppDefaults.load(from: store).reviewBackend == .claudeCode)
    }

    @Test("a repository pinning a Codex model moves the backend with it")
    func aRepoPinnedCodexModelWins() {
        var repo = RepoSettings()
        repo.defaultModel = "gpt-5.5"

        let resolved = ComposerDefaults.resolve(
            repo: repo,
            app: AppDefaults(),
            models: [.codex: Self.codexModels.map(\.agentModel)]
        )
        #expect(resolved.model == "gpt-5.5")
        #expect(resolved.backend == .codex)
    }

    @Test("a repository pinning a Claude model moves it back")
    func aRepoPinnedClaudeModelWins() {
        var repo = RepoSettings()
        repo.defaultModel = "claude-opus-5[1m]"

        let resolved = ComposerDefaults.resolve(
            repo: repo,
            app: AppDefaults(model: "gpt-5.6-sol", backend: .codex),
            models: [.codex: Self.codexModels.map(\.agentModel)]
        )
        #expect(resolved.backend == .claudeCode)
    }

    @Test("a model neither list holds stays on the backend already running")
    func anUnknownModelDoesNotMoveAnything() {
        var repo = RepoSettings()
        repo.defaultModel = "internal-preview-3"

        let opened = ComposerDefaults.resolve(
            repo: repo,
            app: AppDefaults(),
            models: [.codex: Self.codexModels.map(\.agentModel)]
        )
        #expect(opened.backend == .claudeCode)

        let inACodexChat = ComposerDefaults.resolve(
            repo: repo,
            app: AppDefaults(),
            running: .codex,
            models: [.codex: Self.codexModels.map(\.agentModel)]
        )
        #expect(inACodexChat.backend == .codex)
    }

    @Test("a settings file naming the backend in front of the model opens that backend")
    func aNamespacedRepoModelOpensItsOwnBackend() {
        var repo = RepoSettings()
        repo.defaultModel = "codex:gpt-5.6-sol"

        let resolved = ComposerDefaults.resolve(
            repo: repo,
            app: AppDefaults(),
            models: [.codex: Self.codexModels.map(\.agentModel)]
        )
        #expect(resolved.model == "gpt-5.6-sol")
        #expect(resolved.backend == .codex)
    }

    @Test("it opens that backend before any list has answered")
    func aNamespacedModelNeedsNoList() {
        var repo = RepoSettings()
        repo.defaultModel = "codex:gpt-5.6-sol"

        let resolved = ComposerDefaults.resolve(repo: repo, app: AppDefaults())
        #expect(resolved.model == "gpt-5.6-sol")
        #expect(resolved.backend == .codex)
    }

    @Test("the machine-wide file is read the same way")
    func aNamespacedHomeModel() {
        var repo = RepoSettings()
        repo.homeDefaultModel = "codex:gpt-5.5"

        let resolved = ComposerDefaults.resolve(
            repo: repo,
            app: AppDefaults(),
            models: [.codex: Self.codexModels.map(\.agentModel)]
        )
        #expect(resolved.model == "gpt-5.5")
        #expect(resolved.backend == .codex)
    }

    @Test("the name in front of the model beats the backend stored beside it")
    func theNamespaceBeatsTheRecordedBackend() {
        let stale = AppDefaults(model: "codex:gpt-5.6-sol", backend: .claudeCode)
        let resolved = ComposerDefaults.resolve(
            repo: RepoSettings(),
            app: stale,
            models: [.codex: Self.codexModels.map(\.agentModel)]
        )
        #expect(resolved.model == "gpt-5.6-sol")
        #expect(resolved.backend == .codex)
    }

    @Test("the model menu places it in the same section")
    func theMenuPlacesItTheSameWay() {
        #expect(DefaultBackend.kind(
            ofModel: "codex:gpt-5.6-sol", running: .claudeCode, models: [.codex: Self.codexModels.map(\.agentModel)]
        ) == .codex)
        #expect(DefaultBackend.kind(
            ofModel: "claude:opus", running: .codex, models: [.codex: Self.codexModels.map(\.agentModel)]
        ) == .claudeCode)
    }

    @Test("the four families are recognised, including the variants no menu row carries")
    func theFamiliesAreRecognised() {
        #expect(ClaudeModelRank.recognises("opus"))
        #expect(ClaudeModelRank.recognises("claude-opus-5[1m]"))
        #expect(ClaudeModelRank.recognises("opus-5-1m"))
        #expect(!ClaudeModelRank.recognises("gpt-5.6-sol"))
        #expect(!ClaudeModelRank.recognises("gpt-6-astra"))
        #expect(!ClaudeModelRank.recognises("internal-preview-3"))
    }

    @Test("an effort the chosen model does not take falls to the model's default")
    func anImpossibleEffortFallsBack() {
        let resolved = ComposerDefaults.resolve(
            repo: RepoSettings(),
            app: AppDefaults(model: "gpt-5.5", effort: "max", backend: .codex),
            models: [.codex: Self.codexModels.map(\.agentModel)]
        )
        #expect(resolved.effort == "medium")

        let takesIt = ComposerDefaults.resolve(
            repo: RepoSettings(),
            app: AppDefaults(model: "gpt-5.6-sol", effort: "ultra", backend: .codex),
            models: [.codex: Self.codexModels.map(\.agentModel)]
        )
        #expect(takesIt.effort == "ultra")
    }

    @Test("an effort is left alone while the list has not arrived")
    func anEffortIsKeptWithNoList() {
        let resolved = ComposerDefaults.resolve(
            repo: RepoSettings(),
            app: AppDefaults(model: "gpt-5.5", effort: "max", backend: .codex)
        )
        #expect(resolved.effort == "max")
        #expect(resolved.backend == .codex)
    }

    @Test("the plan default uses the backend's planning mechanism")
    func planModeUsesBackendMechanism() {
        var codex = AppDefaults(model: "gpt-5.6-sol", backend: .codex)
        codex.planMode = true
        let resolved = ComposerDefaults.resolve(repo: RepoSettings(), app: codex)
        #expect(resolved.permissionMode == codex.permissionMode)
        #expect(resolved.interactionMode == .plan)

        var claude = AppDefaults()
        claude.planMode = true
        #expect(ComposerDefaults.resolve(repo: RepoSettings(), app: claude).permissionMode == .plan)
    }

    @Test("the controls a workspace is started with hold the same invariant")
    func theControlsLandOnALegalMode() {
        var defaults = AppDefaults(model: "gpt-5.6-sol", backend: .codex)
        defaults.planMode = true

        let controls = ComposerControls(
            defaults: ComposerDefaults.resolve(repo: RepoSettings(), app: defaults),
            isFastMode: false,
            outputStyle: OutputStyle.defaultName
        )
        #expect(controls.agentKind == .codex)
        #expect(controls.permissionMode == defaults.permissionMode)
        #expect(controls.interactionMode == .plan)
        #expect(!controls.offersOutputStyle)
    }
}
