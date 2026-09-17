import Testing
import Foundation
@testable import Core

private func codexEvents(_ name: String) throws -> [CodexEvent] {
    try fixtureLines(name).compactMap { line in
        guard case .notification(let notification)? = CodexFrame.decode(line: line) else { return nil }
        return CodexEvent.decode(notification)
    }
}

private func codexRequests(_ name: String) throws -> [CodexApprovalRequest] {
    try fixtureLines(name).compactMap { line in
        guard case .request(let request)? = CodexFrame.decode(line: line) else { return nil }
        return CodexApprovalRequest.decode(request)
    }
}

private func translated(
    _ name: String,
    context: CodexTranslation.Context = CodexTranslation.Context(model: "gpt-5.6-sol", cwd: "/tmp/w")
) throws -> [AgentEvent] {
    var translation = CodexTranslation(context: context)
    return try codexEvents(name).flatMap { translation.translate($0) }
}

@Suite struct CodexTranslationTests {
    @Test func turnsARecordedTurnIntoOurEvents() throws {
        let events = try translated("codex-turn.ndjson")

        var deltas = ""
        var texts: [String] = []
        var results: [AgentResult] = []
        var inits: [AgentInit] = []

        for event in events {
            switch event {
            case .streamDelta(.text(let chunk)): deltas += chunk
            case .assistantText(let block): texts.append(block.text)
            case .result(let result): results.append(result)
            case .initialized(let value): inits.append(value)
            default: break
            }
        }

        #expect(deltas == "unifieddev")
        #expect(texts == ["unifieddev"])
        #expect(inits.first?.sessionID.isEmpty == false)
        #expect(inits.first?.model == "gpt-5.6-sol")

        let result = try #require(results.first)
        #expect(result.succeeded)
        #expect(result.usage.outputTokens == 6)
        #expect(result.usage.inputTokens == 16159)
        #expect(result.usage.costUSD == 0)
    }

    @Test func everyStoredRowDecodesBackIntoTheSameEvent() throws {
        var checked = 0
        for event in try translated("codex-approval.ndjson") where event.isTranscriptRow {
            let line = String(decoding: event.raw, as: UTF8.self)
            #expect(!line.isEmpty, "a stored row must carry bytes")
            let reread = try #require(AgentEvent.decode(line: line))
            #expect(reread.kind == event.kind, "row kind changed on the way back: \(line.prefix(120))")
            checked += 1
        }
        #expect(checked > 0)
    }

    @Test func aRereadCallKeepsItsNameItsInputAndItsCodexItem() throws {
        let calls = try translated("codex-approval.ndjson").compactMap { event -> AgentToolUse? in
            if case .toolUse(let use) = event { return use }
            return nil
        }
        let patch = try #require(calls.first { $0.name == "ApplyPatch" })
        #expect(patch.filePath?.hasSuffix("note.txt") == true)

        guard case .toolUse(let reread)? = AgentEvent.decode(
            line: String(decoding: patch.raw, as: UTF8.self)
        ) else {
            Issue.record("a stored call did not come back as a call")
            return
        }
        #expect(reread.id == patch.id)
        #expect(reread.name == "ApplyPatch")
        #expect(reread.filePath == patch.filePath)

        #expect(CodexTranslation.isCodexCall(reread.input))
        guard case .fileChange(let change)? = CodexTranslation.item(in: reread.input) else {
            Issue.record("the stored item was not a file change")
            return
        }
        #expect(change.changes.first?.diff.contains("hi") == true)
        #expect(change.changes.first?.kind == .add)
    }

    @Test func aRefusedCallComesBackAsDeniedRatherThanFailed() throws {
        let results = try translated("codex-approval.ndjson").compactMap { event -> AgentToolResult? in
            if case .toolResult(let result) = event { return result }
            return nil
        }
        let declined = try #require(results.first { $0.refusal != nil })
        #expect(declined.refusal == .denied)
        #expect(declined.isError)

        guard case .toolResult(let reread)? = AgentEvent.decode(
            line: String(decoding: declined.raw, as: UTF8.self)
        ) else {
            Issue.record("a stored result did not come back as a result")
            return
        }
        #expect(reread.refusal == .denied)
        #expect(reread.toolUseID == declined.toolUseID)
    }

    @Test func anInterruptedTurnIsNotAFailure() throws {
        let results = try translated("codex-interrupt.ndjson").compactMap { event -> AgentResult? in
            if case .result(let result) = event { return result }
            return nil
        }
        let result = try #require(results.first)
        #expect(result.subtype == "interrupted")
        #expect(!result.isError)
        #expect(result.stopReason == "interrupted")
        #expect(!result.succeeded)
    }

    @Test func theContextWindowEndsUpWhereTheGaugeLooksForIt() throws {
        var translation = CodexTranslation(context: CodexTranslation.Context(model: "gpt-5.6-sol"))
        _ = translation.translate(.tokenUsage(CodexTokenUsage(
            inputTokens: 1_000, outputTokens: 10, totalTokens: 1_010, contextWindow: 272_000
        )))
        let events = translation.translate(.turnCompleted(CodexTurn(
            id: "t", threadID: "th", status: .completed
        )))

        guard case .result(let result)? = events.first else {
            Issue.record("expected a result")
            return
        }
        #expect(result.usage.contextTokens == 272_000)

        guard case .result(let reread)? = AgentEvent.decode(
            line: String(decoding: result.raw, as: UTF8.self)
        ) else {
            Issue.record("the stored result did not come back")
            return
        }
        #expect(reread.usage.contextTokens == 272_000)
        #expect(reread.usage.contextUsedTokens == 1_000)
    }

    @Test func theUsersOwnMessageIsNotEchoedIntoTheTranscript() throws {
        let users = try translated("codex-turn.ndjson").filter { $0.kind == .user }
        #expect(users.isEmpty)
    }

    @Test func anEmptyReasoningItemDrawsNothing() throws {
        let thinking = try translated("codex-approval.ndjson").filter {
            if case .thinking = $0 { return true }
            return false
        }
        #expect(thinking.isEmpty)
    }

    @Test func theNoisyNotificationsAreDroppedRatherThanStored() throws {
        let events = try translated("codex-turn.ndjson")
        #expect(!events.contains { if case .unknown = $0 { return true } else { return false } })
    }

    @Test func namesEachItemInCodexsOwnWords() {
        #expect(CodexTranslation.toolName(for: .commandExecution(
            CodexCommandExecution(id: "1", command: "ls")
        )) == "Shell")
        #expect(CodexTranslation.toolName(for: .fileChange(
            CodexFileChange(id: "1", changes: [])
        )) == "ApplyPatch")
        #expect(CodexTranslation.toolName(for: .mcpToolCall(
            CodexMcpToolCall(id: "1", server: "figma", tool: "get_screenshot")
        )) == "mcp__figma__get_screenshot")
        #expect(CodexTranslation.toolName(for: .other(type: "sleep", id: "1", json: .null)) == "Codex.sleep")
    }

    @Test func theWorkingLabelFollowsTheThreadStatus() {
        var translation = CodexTranslation()
        let working = translation.translate(.threadStatus(CodexThreadStatus(
            threadID: "t", state: .active, activeFlags: []
        )))
        let waiting = translation.translate(.threadStatus(CodexThreadStatus(
            threadID: "t", state: .active, activeFlags: ["waitingOnApproval"]
        )))
        let idle = translation.translate(.threadStatus(CodexThreadStatus(threadID: "t", state: .idle)))

        #expect(working.count == 1)
        #expect(waiting.count == 1)
        #expect(idle.isEmpty)
        if case .status(let label)? = waiting.first {
            #expect(label == "Waiting on you")
        } else {
            Issue.record("expected a status")
        }
    }

    @Test func aRetriedFailureDrawsNothing() {
        var translation = CodexTranslation()
        let retried = translation.translate(.turnError(CodexTurnError(
            threadID: "t", turnID: "u", message: "stream closed", willRetry: true
        )))
        let final = translation.translate(.turnError(CodexTurnError(
            threadID: "t", turnID: "u", message: "stream closed", willRetry: false
        )))
        #expect(retried.isEmpty)
        #expect(final.count == 1)
    }

    @Test func aTurnErrorIsStoredInTheShapeTheErrorRowReads() {
        var translation = CodexTranslation()
        let events = translation.translate(.turnError(CodexTurnError(
            threadID: "t", turnID: "u", message: "The model refused the request", willRetry: false
        )))
        guard case .error(let failure)? = events.first else {
            Issue.record("expected an error")
            return
        }
        let exit = AgentExit.decode(failure.raw)
        #expect(exit.summary.contains("refused") || exit.detail.contains("refused"))
    }
}

@Suite struct CodexPermissionTests {
    private func recordedAsk() throws -> (PermissionAsk, CodexApprovalRequest) {
        let request = try #require(try codexRequests("codex-approval.ndjson").first)
        let item = try codexEvents("codex-approval.ndjson").compactMap { event -> CodexItem? in
            if case .itemStarted(let started) = event, started.item.id == request.itemID {
                return started.item
            }
            return nil
        }.first
        return (CodexPermission.ask(for: request, item: item), request)
    }

    @Test func buildsAQuestionFromTheRecordedRequestAndTheItemBeforeIt() throws {
        let (ask, request) = try recordedAsk()

        #expect(ask.toolName == "ApplyPatch")
        #expect(ask.displayName == "Change files")
        #expect(ask.toolUseID == request.itemID)
        #expect(ask.subject.hasSuffix("note.txt"))
        #expect(ask.summary.hasPrefix("Created"))
        #expect(ask.canWiden)
        #expect(ask.rules.count == 1)
        #expect(ask.rules.first?.toolName == "ApplyPatch")
        #expect(ask.rules.first?.ruleContent?.hasSuffix("note.txt") == true)
    }

    @Test func aStoredQuestionCanBeRebuiltFromItsBytes() throws {
        let (ask, _) = try recordedAsk()
        let reread = try #require(PermissionAsk.decode(payload: ask.raw))

        #expect(reread.requestID == ask.requestID)
        #expect(reread.toolName == ask.toolName)
        #expect(reread.toolUseID == ask.toolUseID)
        #expect(reread.subject == ask.subject)
        #expect(reread.rules == ask.rules)
        #expect(reread.canWiden == ask.canWiden)
        #expect(CodexTranslation.isCodexCall(reread.input))
    }

    @Test func aQuestionsIDCannotCollideWithTheNextConnections() {
        let first = CodexPermission.requestID(.number(0), threadID: "thread-a")
        let second = CodexPermission.requestID(.number(0), threadID: "thread-b")
        #expect(first != second)
        #expect(first.hasPrefix("codex:"))
    }

    @Test func offersNoPersistentRuleForTheKindsThatHaveNoRule() {
        for kind in [CodexApprovalRequest.Kind.permissions, .mcpElicitation, .toolUserInput] {
            let ask = CodexPermission.ask(
                for: CodexApprovalRequest(
                    id: .number(1), kind: kind, threadID: "t", turnID: "u", itemID: "i",
                    params: .object([:])
                ),
                item: nil
            )
            #expect(ask.suppressesAlwaysAllow)
            #expect(!ask.canWiden)
            #expect(ask.rules.isEmpty)
        }
    }

    @Test func aShellRuleIsTheCommandVerbatim() {
        let item = CodexItem.commandExecution(CodexCommandExecution(
            id: "exec-1", command: "/bin/zsh -lc 'rm -rf build'", cwd: "/tmp/w"
        ))
        let ask = CodexPermission.ask(
            for: CodexApprovalRequest(
                id: .number(2), kind: .commandExecution, threadID: "t", turnID: "u", itemID: "exec-1",
                params: .object(["command": .string("/bin/zsh -lc 'rm -rf build'")])
            ),
            item: item
        )
        #expect(ask.toolName == "Shell")
        #expect(ask.rules.first?.ruleContent == "/bin/zsh -lc 'rm -rf build'")
        #expect(ask.ruleText == "Shell(/bin/zsh -lc 'rm -rf build')")
        #expect(ask.subject == "/bin/zsh -lc 'rm -rf build'")
    }

    @Test func mapsEveryDecisionOntoCodexsOwnVocabulary() {
        #expect(CodexPermission.decision(for: .allow(scope: .once)) == .accept)
        #expect(CodexPermission.decision(for: .allow(scope: .session)) == .acceptForSession)
        #expect(CodexPermission.decision(for: .allow(scope: .project)) == .acceptForSession)
        #expect(CodexPermission.decision(for: .deny(message: "no", endsTurn: false)) == .decline)
        #expect(CodexPermission.decision(for: .deny(message: "no", endsTurn: true)) == .cancel)
    }

    @Test func aStoredGrantMatchesTheQuestionItWasGrantedFor() throws {
        let (ask, _) = try recordedAsk()
        let rule = try #require(ask.rules.first)
        let grant = PermissionGrant(
            repoID: RepoID("repo"),
            toolName: rule.toolName,
            ruleContent: rule.ruleContent
        )
        #expect(PermissionGrantIndex.match(ask: ask, grants: [grant])?.count == 1)

        let other = PermissionGrant(repoID: RepoID("repo"), toolName: "ApplyPatch", ruleContent: "/tmp/other")
        #expect(PermissionGrantIndex.match(ask: ask, grants: [other]) == nil)
    }
}

@Suite struct CodexPatchCountingTests {
    @Test func aRecordedPatchCarriesADiffThatCanBeCounted() throws {
        let change = try fixtureLines("codex-approval.ndjson")
            .compactMap { line -> CodexFileChange? in
                guard case .notification(let notification)? = CodexFrame.decode(line: line),
                      case .itemStarted(let started) = CodexEvent.decode(notification),
                      case .fileChange(let change) = started.item
                else { return nil }
                return change
            }
            .first
        let patch = try #require(change)
        let update = try #require(patch.changes.first)

        #expect(update.kind == .add)
        #expect(update.diff == "hi\n")
        #expect(!update.diff.contains("@@"))
        #expect(update.addedLines == 1)
        #expect(update.removedLines == 0)
    }

    @Test func anEditCarriesAHunkAndCountsBothWays() throws {
        let change = try fixtureLines("codex-edit-patch.ndjson")
            .compactMap { line -> CodexFileChange? in
                guard case .notification(let notification)? = CodexFrame.decode(line: line),
                      case .itemCompleted(let completed) = CodexEvent.decode(notification),
                      case .fileChange(let change) = completed.item
                else { return nil }
                return change
            }
            .first
        let patch = try #require(change)
        let update = try #require(patch.changes.first)

        #expect(update.kind == .update(movedTo: nil))
        #expect(update.diff.hasPrefix("@@"))
        #expect(!update.diff.contains("+++"))
        #expect(update.addedLines == 1)
        #expect(update.removedLines == 1)
    }

    @Test func countsAWholeFileByItsLinesRatherThanItsMarkers() {
        let added = CodexFileUpdate(path: "a.txt", diff: "one\ntwo\nthree\n", kind: .add)
        #expect(added.addedLines == 3)
        #expect(added.removedLines == 0)

        let removed = CodexFileUpdate(path: "a.txt", diff: "one\ntwo\n", kind: .delete)
        #expect(removed.addedLines == 0)
        #expect(removed.removedLines == 2)

        #expect(CodexFileUpdate(path: "a", diff: "hi", kind: .add).addedLines == 1)
        #expect(CodexFileUpdate(path: "a", diff: "", kind: .add).addedLines == 0)
    }
}
