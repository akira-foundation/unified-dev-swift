import Testing
import Foundation
@testable import Core

private func codexFixture(_ name: String) throws -> [String] {
    try fixtureLines(name)
}

private func codexFixtureJSON(_ name: String) throws -> JSONValue {
    let text = try fixtureLines(name).joined(separator: "\n")
    return try #require(JSONValue.parse(text))
}

private func frames(_ name: String) throws -> [CodexFrame] {
    try codexFixture(name).compactMap { CodexFrame.decode(line: $0) }
}

private func notifications(_ name: String) throws -> [CodexServerNotification] {
    try frames(name).compactMap {
        if case .notification(let notification) = $0 { return notification }
        return nil
    }
}

private func events(_ name: String) throws -> [CodexEvent] {
    try notifications(name).map(CodexEvent.decode)
}

@Suite struct CodexFrameTests {
    @Test func classifiesEveryFrameInARecordedTurn() throws {
        let decoded = try frames("codex-turn.ndjson")

        var responses = 0, notificationCount = 0, requests = 0, malformed = 0
        for frame in decoded {
            switch frame {
            case .response: responses += 1
            case .failure: malformed += 1
            case .request: requests += 1
            case .notification: notificationCount += 1
            case .malformed: malformed += 1
            }
        }

        #expect(decoded.count == 21)
        #expect(responses == 3)
        #expect(notificationCount == 18)
        #expect(requests == 0)
        #expect(malformed == 0)
    }

    @Test func recordedFramesCarryNoJSONRPCMember() throws {
        for line in try codexFixture("codex-turn.ndjson") {
            let json = try #require(JSONValue.parse(line))
            #expect(json["jsonrpc"] == nil)
        }
    }

    @Test func readsAServerRequestOutOfTheApprovalRecording() throws {
        let requests = try frames("codex-approval.ndjson").compactMap { frame -> CodexServerRequest? in
            if case .request(let request) = frame { return request }
            return nil
        }

        #expect(requests.count == 1)
        let request = try #require(requests.first)
        #expect(request.method == "item/fileChange/requestApproval")
        #expect(request.id == .number(0))
        #expect(request.params["itemId"]?.stringValue?.hasPrefix("exec-") == true)
    }

    @Test func readsAFailureResponse() throws {
        let line = """
        {"error":{"code":-32600,"message":"Invalid request: missing field `turnId`"},"id":4}
        """
        guard case .failure(let id, let error, _) = try #require(CodexFrame.decode(line: line)) else {
            Issue.record("expected a failure frame")
            return
        }
        #expect(id == .number(4))
        #expect(error.code == -32600)
        #expect(error.message.contains("turnId"))
    }

    @Test func aNullResultIsStillAResponse() throws {
        guard case .response(_, let result, _) = try #require(CodexFrame.decode(line: #"{"id":1,"result":null}"#)) else {
            Issue.record("expected a response frame")
            return
        }
        #expect(result.isNull)
    }

    @Test func nonJSONSurvivesAsMalformedRatherThanEndingTheSession() {
        #expect(CodexFrame.decode(line: "") == nil)
        #expect(CodexFrame.decode(line: "   ") == nil)
        if case .malformed = CodexFrame.decode(line: "warning: something") {} else {
            Issue.record("expected malformed")
        }
        if case .malformed = CodexFrame.decode(line: "[1,2,3]") {} else {
            Issue.record("expected malformed for a non-object document")
        }
    }

    @Test func buildsOutgoingFramesThatAreOneLine() {
        let request = CodexOutgoing.request(
            id: .number(7),
            method: "turn/start",
            params: .object(["threadId": .string("t")])
        )
        #expect(!request.contains("\n"))
        #expect(request.contains("\"id\":7"))
        #expect(request.contains("\"method\":\"turn/start\""))

        let answer = CodexOutgoing.response(id: .number(0), result: .object(["decision": .string("decline")]))
        #expect(answer == #"{"jsonrpc":"2.0","id":0,"result":{"decision":"decline"}}"#)

        let notification = CodexOutgoing.notification(method: "initialized", params: nil)
        #expect(notification == #"{"jsonrpc":"2.0","method":"initialized"}"#)
    }

    @Test func omittedParametersAreLeftOutRatherThanSentAsNull() {
        let params = JSONValue.object(omittingNil: [
            "cwd": .string("/tmp"),
            "model": nil,
            "sandbox": nil,
        ])
        #expect(params.objectValue?.count == 1)
        #expect(params.compactJSON == #"{"cwd":"/tmp"}"#)
    }

    @Test func stringAndNumberIDsBothRoundTrip() {
        #expect(CodexRequestID.number(12).jsonLiteral == "12")
        #expect(CodexRequestID.text("abc").jsonLiteral == "\"abc\"")
    }
}

@Suite struct CodexEventTests {
    @Test func readsAWholeTurnOffTheRecording() throws {
        let decoded = try events("codex-turn.ndjson")

        var deltas: [String] = []
        var completedItems: [CodexItem] = []
        var finishedTurn: CodexTurn?
        var usage: CodexTokenUsage?
        var statuses: [CodexThreadStatus.State] = []
        var unknownMethods: [String] = []

        for event in decoded {
            switch event {
            case .agentMessageDelta(let delta): deltas.append(delta.text)
            case .itemCompleted(let item): completedItems.append(item.item)
            case .turnCompleted(let turn): finishedTurn = turn
            case .tokenUsage(let value): usage = value
            case .threadStatus(let status): statuses.append(status.state)
            case .unknown(let method, _): unknownMethods.append(method)
            default: break
            }
        }

        #expect(deltas.joined() == "unifieddev")
        #expect(completedItems.count == 2)
        guard case .agentMessage(let message) = completedItems.last else {
            Issue.record("expected the last completed item to be an agent message")
            return
        }
        #expect(message.text == "unifieddev")
        #expect(message.phase == .finalAnswer)

        let turn = try #require(finishedTurn)
        #expect(turn.status == .completed)
        #expect(turn.succeeded)
        #expect(turn.durationMS ?? 0 > 0)

        let tokens = try #require(usage)
        #expect(tokens.totalTokens == 16165)
        #expect(tokens.outputTokens == 6)
        #expect(tokens.cachedInputTokens == 11008)

        #expect(statuses == [.active, .idle])
        #expect(unknownMethods.contains("mcpServer/startupStatus/updated"))
    }

    @Test func readsTheLatestRequestRatherThanTheCumulativeThreadUsage() throws {
        let usage = try #require(events("codex-approval.ndjson").compactMap {
            if case .tokenUsage(let value) = $0 { return value }
            return nil
        }.first)

        #expect(usage.inputTokens == 16_615)
        #expect(usage.totalTokens == 16_620)
        #expect(usage.contextWindow == 258_400)
    }

    @Test func readsTheUserMessageItem() throws {
        let started = try events("codex-turn.ndjson").compactMap { event -> CodexItem? in
            if case .itemStarted(let item) = event { return item.item }
            return nil
        }
        guard case .userMessage(let message) = started.first else {
            Issue.record("expected a user message first")
            return
        }
        #expect(message.text == "Reply with exactly one word: unifieddev")
        #expect(message.imagePaths.isEmpty)
    }

    @Test func readsAFileChangeAndTheApprovalThatWasAskedAboutIt() throws {
        let decoded = try frames("codex-approval.ndjson")

        var fileChange: CodexFileChange?
        var approval: CodexApprovalRequest?
        var declinedStatus: CodexRunStatus?

        for frame in decoded {
            switch frame {
            case .request(let request):
                approval = CodexApprovalRequest.decode(request)
            case .notification(let notification):
                if case .itemStarted(let event) = CodexEvent.decode(notification),
                   case .fileChange(let change) = event.item {
                    fileChange = change
                }
                if case .itemCompleted(let event) = CodexEvent.decode(notification),
                   case .fileChange(let change) = event.item {
                    declinedStatus = change.status
                }
            default: break
            }
        }

        let change = try #require(fileChange)
        #expect(change.changes.count == 1)
        let update = try #require(change.changes.first)
        #expect(update.path.hasSuffix("note.txt"))
        #expect(update.diff.contains("hi"))
        #expect(update.kind == .add)

        let request = try #require(approval)
        #expect(request.kind == .fileChange)
        #expect(request.itemID == change.id)
        #expect(!request.threadID.isEmpty)
        #expect(!request.turnID.isEmpty)

        #expect(declinedStatus == .declined)
    }

    @Test func readsTheWaitingOnApprovalFlag() throws {
        let waiting = try events("codex-approval.ndjson").contains { event in
            if case .threadStatus(let status) = event { return status.isWaitingOnApproval }
            return false
        }
        #expect(waiting)
    }

    @Test func readsAnAgentMessagePhase() throws {
        let phases = try events("codex-approval.ndjson").compactMap { event -> CodexMessagePhase? in
            guard case .itemCompleted(let item) = event, case .agentMessage(let message) = item.item else {
                return nil
            }
            return message.phase
        }
        #expect(phases == [.commentary, .finalAnswer])
    }

    @Test func readsAnInterruptedTurn() throws {
        let statuses = try events("codex-interrupt.ndjson").compactMap { event -> CodexTurn.Status? in
            if case .turnCompleted(let turn) = event { return turn.status }
            return nil
        }
        #expect(statuses == [.interrupted])
        #expect(statuses.first?.rawValue != CodexTurn.Status.completed.rawValue)
    }

    @Test func deltasAreNotTranscriptRows() {
        let delta = CodexTextDelta(itemID: "i", threadID: "t", turnID: "u", text: "x")
        #expect(!CodexEvent.agentMessageDelta(delta).isTranscriptRow)
        #expect(!CodexEvent.reasoningDelta(delta).isTranscriptRow)
        #expect(CodexEvent.itemCompleted(CodexItemEvent(
            item: .agentMessage(CodexAgentMessage(id: "i", text: "x")),
            threadID: "t",
            turnID: "u"
        )).isTranscriptRow)
    }

    @Test func anUnknownItemTypeKeepsItsPayload() throws {
        let json = try #require(JSONValue.parse(#"{"type":"quantumFoo","id":"x","weight":3}"#))
        let item = try #require(CodexItem.decode(json))
        #expect(item.typeName == "quantumFoo")
        #expect(item.id == "x")
        guard case .other(_, _, let payload) = item else {
            Issue.record("expected .other")
            return
        }
        #expect(payload["weight"]?.intValue == 3)
    }

    @Test func mapsTokensOntoOurUsageWithoutDoubleCountingTheCache() {
        let usage = CodexTokenUsage(
            inputTokens: 16159,
            cachedInputTokens: 11008,
            outputTokens: 6,
            reasoningOutputTokens: 4,
            totalTokens: 16165,
            contextWindow: 272_000
        )
        let mapped = usage.agentUsage
        #expect(mapped.inputTokens == 16159)
        #expect(mapped.contextUsedTokens == 16159)
        #expect(mapped.thinkingTokens == 4)
        #expect(mapped.contextTokens == 272_000)
        #expect(mapped.costUSD == 0)
    }

    @Test func spellsEachApprovalDecisionTheWayItsOwnResponseSchemaDoes() {
        let decline = CodexApprovalDecision.decline
        #expect(decline.result(for: .commandExecution).compactJSON == #"{"decision":"decline"}"#)
        #expect(decline.result(for: .fileChange).compactJSON == #"{"decision":"decline"}"#)
        #expect(decline.result(for: .mcpElicitation).compactJSON == #"{"action":"decline"}"#)
        #expect(CodexApprovalDecision.acceptForSession.result(for: .mcpElicitation)
            .compactJSON == #"{"action":"accept"}"#)
    }
}

@Suite struct CodexModelTests {
    @Test func readsTheRecordedModelList() throws {
        let models = CodexModel.decodeList(try codexFixtureJSON("codex-model-list.json"))
        #expect(models.map(\.id) == [
            "gpt-5.6-sol", "gpt-5.6-terra", "gpt-5.6-luna", "gpt-5.5", "gpt-5.2",
        ])
        #expect(models.filter(\.isDefault).map(\.id) == ["gpt-5.6-sol"])
        #expect(models.filter(\.hidden).isEmpty)
    }

    @Test func everyModelBringsItsOwnEfforts() throws {
        let models = CodexModel.decodeList(try codexFixtureJSON("codex-model-list.json"))
        let byID = Dictionary(uniqueKeysWithValues: models.map { ($0.id, $0) })

        #expect(byID["gpt-5.6-sol"]?.effortIDs == ["low", "medium", "high", "xhigh", "max", "ultra"])
        #expect(byID["gpt-5.6-luna"]?.effortIDs == ["low", "medium", "high", "xhigh", "max"])
        #expect(byID["gpt-5.5"]?.effortIDs == ["low", "medium", "high", "xhigh"])
        #expect(byID["gpt-5.2"]?.effortIDs == ["low", "medium", "high", "xhigh"])

        #expect(byID["gpt-5.6-sol"]?.defaultEffort == "low")
        #expect(byID["gpt-5.5"]?.defaultEffort == "medium")
    }

    @Test func fallsBackToTheModelsOwnDefaultWhenAnEffortDoesNotApply() throws {
        let models = CodexModel.decodeList(try codexFixtureJSON("codex-model-list.json"))
        let luna = try #require(models.first { $0.id == "gpt-5.6-luna" })
        let five = try #require(models.first { $0.id == "gpt-5.5" })

        #expect(luna.resolvedEffort(preferring: "max") == "max")
        #expect(luna.resolvedEffort(preferring: "ultra") == "medium")
        #expect(five.resolvedEffort(preferring: "max") == "medium")
    }

    @Test func carriesTheDescriptionTheServerWroteForEachEffort() throws {
        let models = CodexModel.decodeList(try codexFixtureJSON("codex-model-list.json"))
        let sol = try #require(models.first { $0.id == "gpt-5.6-sol" })
        #expect(sol.supportedEfforts.filter { $0.description.isEmpty }.isEmpty)
        #expect(sol.supportedEfforts.first { $0.id == "xhigh" }?.label == "Extra high")
        #expect(sol.supportedEfforts.first { $0.id == "low" }?.label == "Low")
    }

    @Test func readsWhichModelsTakeAnImage() throws {
        let models = CodexModel.decodeList(try codexFixtureJSON("codex-model-list.json"))
        #expect(models.filter(\.acceptsImages).count == models.count)
    }

    @Test func readsAGenerationOfModelsNothingHereHadHeardOf() throws {
        let models = CodexModel.decodeList(try codexFixtureJSON("codex-model-list-astra.json"))
        let astra = try #require(models.first { $0.id == "gpt-6-astra" })

        #expect(astra.displayName == "GPT-6-Astra")
        #expect(astra.isDefault)
        #expect(astra.acceptsImages)
        #expect(astra.effortIDs == ["low", "medium", "high", "xhigh", "max", "ultra"])
        #expect(astra.defaultEffort == "medium")
        #expect(astra.resolvedEffort(preferring: "ultra") == "ultra")
    }

    @Test func offersTheNewGenerationAboveEverythingItSupersedes() throws {
        let models = CodexModel.decodeList(try codexFixtureJSON("codex-model-list-astra.json"))
        #expect(CodexModelRank.ordered(models).map(\.id) == [
            "gpt-6-astra",
            "gpt-5.6-sol", "gpt-5.6-terra", "gpt-5.6-luna",
            "gpt-5.5", "gpt-5.4-mini", "gpt-5.3-codex-spark",
        ])
    }
}

@Suite struct CodexModelCatalogTests {
    private func catalog(counter: Counter, models: [CodexModel]) -> CodexModelCatalog {
        CodexModelCatalog(fetch: {
            counter.bump()
            try await Task.sleep(for: .milliseconds(20))
            return models
        })
    }

    private final class Counter: @unchecked Sendable {
        private let lock = NSLock()
        private var value = 0
        func bump() { lock.lock(); value += 1; lock.unlock() }
        var count: Int { lock.lock(); defer { lock.unlock() }; return value }
    }

    private let sample = [
        CodexModel(id: "b", displayName: "B", supportedEfforts: [CodexReasoningEffort(id: "low")]),
        CodexModel(id: "a", displayName: "A", isDefault: true, supportedEfforts: [
            CodexReasoningEffort(id: "low"), CodexReasoningEffort(id: "high"),
        ]),
        CodexModel(id: "hidden", displayName: "Hidden", hidden: true),
    ]

    @Test func fetchesOnceAndServesTheRestFromTheCache() async throws {
        let counter = Counter()
        let catalog = catalog(counter: counter, models: sample)

        _ = try await catalog.models()
        _ = try await catalog.models()
        _ = try await catalog.models()

        #expect(counter.count == 1)
        #expect(await catalog.fetchCount == 1)
    }

    @Test func callersArrivingTogetherShareOneFetch() async throws {
        let counter = Counter()
        let catalog = catalog(counter: counter, models: sample)

        async let first = catalog.models()
        async let second = catalog.models()
        async let third = catalog.models()
        _ = try await (first, second, third)

        #expect(counter.count == 1)
    }

    @Test func invalidatingMakesTheNextCallFetchAgain() async throws {
        let counter = Counter()
        let catalog = catalog(counter: counter, models: sample)

        _ = try await catalog.models()
        await catalog.invalidate()
        _ = try await catalog.models()

        #expect(counter.count == 2)
    }

    @Test func keepsTheServersOrderWhenNothingRanksTheModels() async throws {
        let catalog = catalog(counter: Counter(), models: sample)
        let models = try await catalog.models()
        #expect(models.map(\.id) == ["b", "a", "hidden"])
        let visible = try await catalog.pickerModels()
        #expect(visible.map(\.id) == ["b", "a"])
    }

    @Test func handsBackTheEffortsForOneModel() async throws {
        let catalog = catalog(counter: Counter(), models: sample)
        let known = try await catalog.efforts(for: "a")
        #expect(known.map(\.id) == ["low", "high"])
        let unknown = try await catalog.efforts(for: "nope")
        #expect(unknown.isEmpty)
    }
}
