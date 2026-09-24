import Foundation
import Testing
@testable import Core

@Suite("A model the CLI refuses", .tags(.agentProtocol))
struct ModelRefusalTests {
    static let measured = "[claude-code:unrecognized_model] "
        + #"{"model":"definitely-not-a-model","query_source":"sdk"}"#

    @Test("the line the CLI prints names the model it would not take")
    func readsTheModel() {
        #expect(ModelRefusal.model(inStderr: Self.measured) == "definitely-not-a-model")
    }

    @Test("a marker with nothing readable behind it is still a refusal")
    func readsAMarkerWithNoModel() {
        #expect(ModelRefusal.model(inStderr: ModelRefusal.marker) == "")
    }

    @Test("the refusal is found among the other lines the CLI prints")
    func readsTheModelAmongOtherLines() {
        let stderr = "warming up\n\(Self.measured)\nnode:internal/process\n"

        #expect(ModelRefusal.model(inStderr: stderr) == "definitely-not-a-model")
    }

    @Test("ordinary output is not read as a refusal", arguments: [
        "", "error: not logged in", "claude-code: something else entirely",
    ])
    func leavesOtherOutputAlone(stderr: String) {
        #expect(ModelRefusal.model(inStderr: stderr) == nil)
    }

    @Test("a turn that reached its result still ends on a row when the model was refused")
    func survivesAFinishedResult() throws {
        let run = UnfinishedRun.of(
            status: 1, sawResult: true, state: .idle, stderr: Self.measured, command: "claude"
        )

        #expect(try #require(run).leftATurnOpen == false)
    }

    @Test("a turn that reached its result on any other failure stays quiet")
    func staysQuietOnOtherFailures() {
        #expect(UnfinishedRun.of(
            status: 1, sawResult: true, state: .idle, stderr: "error: overloaded", command: "claude"
        ) == nil)
    }

    @Test("the row names the model and says the turn cannot be sent again as it stands")
    func explainsTheRefusal() {
        let exit = AgentExit(
            status: 1, cause: .modelRefused("definitely-not-a-model"), detail: Self.measured
        )

        #expect(exit.title == "Model not available")
        #expect(exit.summary.contains("definitely-not-a-model"))
        #expect(exit.advice.contains("choose another model"))
    }

    @Test("the whole measured ending reads as a refusal rather than as a crash")
    func decodesTheMeasuredEnding() {
        let payload = AgentExitTests.payload(status: 1, stderr: Self.measured, command: "claude")
        let exit = AgentExit.decode(payload)

        #expect(exit.cause == .modelRefused("definitely-not-a-model"))
    }
}
