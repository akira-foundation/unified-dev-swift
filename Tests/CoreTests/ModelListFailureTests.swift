import Testing
@testable import Core

@Suite("Saying why a model list could not be read")
struct ModelListFailureTests {
    private struct Refusal: Error, CustomStringConvertible {
        let description: String
    }

    private func failure(
        _ kind: AgentKind, saying words: String = "not signed in", installed: Bool = true
    ) -> ModelListFailure {
        ModelListFailure(kind: kind, error: Refusal(description: words), agentIsInstalled: installed)
    }

    @Test("the sentence names the agent and carries the CLI's own words")
    func carriesTheCLIsWords() {
        let closed = ModelListFailure(
            kind: .codex, error: CodexClientError.connectionClosed("401 Unauthorized"), agentIsInstalled: true
        )

        #expect(closed.sentence == "Codex could not list its models. The connection to Codex closed: 401 Unauthorized.")
    }

    @Test("a complaint over several lines reads as one")
    func complaintIsOneLine() {
        #expect(failure(.grok, saying: "first line\n\n   second line\n").complaint == "First line second line.")
    }

    @Test("an agent that is not installed is not reported as failing")
    func notInstalledIsNotReported() {
        let failures: [AgentKind: ModelListFailure] = [
            .codex: failure(.codex, installed: false),
            .grok: failure(.grok),
        ]

        #expect(ModelListFailure.reported(failures).map(\.kind) == [.grok])
    }

    @Test("failures are reported in the order the agents are listed")
    func reportedInAgentOrder() {
        let failures = Dictionary(uniqueKeysWithValues: AgentKind.allCases.reversed().map { ($0, failure($0)) })

        #expect(ModelListFailure.reported(failures).map(\.kind) == AgentKind.allCases)
    }

    @Test("the wait for an agent's models ends only once that agent has failed and nothing is loading")
    func givingUp() {
        let failures: [AgentKind: ModelListFailure] = [.grok: failure(.grok)]

        #expect(ModelListFailure.hasGivenUp(on: .grok, among: failures, isLoading: false))
        #expect(!ModelListFailure.hasGivenUp(on: .grok, among: failures, isLoading: true))
        #expect(!ModelListFailure.hasGivenUp(on: .codex, among: failures, isLoading: false))
    }

    @Test("a source records whether its agent is installed when it fails", arguments: [true, false])
    func sourceAsksWhetherTheAgentIsInstalled(installed: Bool) async {
        let source = AgentModelSource(models: { [] }, invalidate: {}, isInstalled: { installed })

        let failed = await source.failure(of: .grok, because: Refusal(description: "no"))

        #expect(failed.kind == .grok)
        #expect(failed.agentIsInstalled == installed)
    }

    @Test("a source that does not say is taken to have its agent installed")
    func installedByDefault() async {
        let source = AgentModelSource(models: { [] }, invalidate: {})

        #expect(await source.failure(of: .grok, because: Refusal(description: "no")).agentIsInstalled)
    }
}
