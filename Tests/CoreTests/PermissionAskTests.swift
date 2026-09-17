import Foundation
import Testing
@testable import Core

@Suite("Permission asks")
struct PermissionAskTests {
    static let realAsk = """
    {"type":"control_request","request_id":"2f9899b1-849f-4d1b-b4b2-9c6e1304b300",\
    "request":{"subtype":"can_use_tool","tool_name":"Bash","display_name":"Bash",\
    "input":{"command":"sudo -n true","description":"Test sudo access without password"},\
    "description":"Test sudo access without password",\
    "permission_suggestions":[{"type":"addRules","rules":[{"toolName":"Bash",\
    "ruleContent":"sudo -n true"}],"behavior":"allow","destination":"localSettings"}],\
    "decision_reason":"This command requires approval","decision_reason_type":"other",\
    "tool_use_id":"toolu_01AtAvbhP1XGtDNmpbSCSBRf"}}
    """

    static func ask(_ line: String = realAsk) -> PermissionAsk {
        guard case .permissionAsk(let ask) = AgentEvent.decode(line: line) else {
            Issue.record("the line did not decode as a permission ask")
            return PermissionAsk(requestID: "", toolName: "")
        }
        return ask
    }

    static func object(_ text: String) -> JSONValue {
        JSONValue.parse(text) ?? .null
    }

    @Test("the sixth event type is no longer dropped")
    func decodesAsAnEvent() {
        guard case .permissionAsk = AgentEvent.decode(line: Self.realAsk) else {
            Issue.record("a control request still decodes as something else")
            return
        }
    }

    @Test("a real ask is read whole")
    func readsTheAsk() {
        let ask = Self.ask()

        #expect(ask.requestID == "2f9899b1-849f-4d1b-b4b2-9c6e1304b300")
        #expect(ask.toolName == "Bash")
        #expect(ask.toolUseID == "toolu_01AtAvbhP1XGtDNmpbSCSBRf")
        #expect(ask.reason == "This command requires approval")
        #expect(ask.reasonType == "other")
        #expect(ask.subject == "sudo -n true")
        #expect(ask.input["command"]?.stringValue == "sudo -n true")
    }

    @Test("the rule that would stop it asking is the CLI's own")
    func carriesTheRule() {
        let ask = Self.ask()

        #expect(ask.rules == [PermissionRule(toolName: "Bash", ruleContent: "sudo -n true")])
        #expect(ask.ruleText == "Bash(sudo -n true)")
        #expect(ask.canWiden)
    }

    @Test("the ask is filed under the call it is about")
    func refersToTheCall() {
        let event = AgentEvent.decode(line: Self.realAsk)

        #expect(event?.refID == "toolu_01AtAvbhP1XGtDNmpbSCSBRf")
        #expect(event?.kind == .permissionAsk)
        #expect(event?.isTranscriptRow == true)
    }

    @Test("an ask survives a round trip through the database")
    func rebuildsFromStoredBytes() {
        let ask = Self.ask()

        #expect(PermissionAsk.decode(payload: ask.raw) == ask)
    }

    @Test("a suppressed rule is not offered as a button even though one was suggested")
    func suppressAlwaysAllow() {
        let ask = Self.ask(Self.realAsk.replacingOccurrences(
            of: #""decision_reason_type":"other""#,
            with: #""decision_reason_type":"other","suppress_always_allow_rule":true"#
        ))

        #expect(ask.suppressesAlwaysAllow)
        #expect(!ask.rules.isEmpty)
        #expect(!ask.canWiden)
    }

    @Test("an ask needing its own surface offers no widening either")
    func requiresUserInteraction() {
        let ask = Self.ask(Self.realAsk.replacingOccurrences(
            of: #""decision_reason_type":"other""#,
            with: #""decision_reason_type":"other","requires_user_interaction":true"#
        ))

        #expect(ask.requiresUserInteraction)
        #expect(!ask.canWiden)
    }

    @Test("no suggestion means no rule, not a rule Unified Dev made up")
    func noSuggestion() {
        let ask = Self.ask(Self.realAsk.replacingOccurrences(
            of: #""permission_suggestions":[{"type":"addRules","rules":[{"toolName":"Bash","ruleContent":"sudo -n true"}],"behavior":"allow","destination":"localSettings"}],"#,
            with: ""
        ))

        #expect(ask.rules.isEmpty)
        #expect(ask.ruleText.isEmpty)
        #expect(!ask.canWiden)
        #expect(ask.allowSuggestion == nil)
    }

    @Test("two allow suggestions for the same tool means none is chosen")
    func ambiguousSuggestions() {
        let ask = Self.ask(Self.realAsk.replacingOccurrences(
            of: #""behavior":"allow","destination":"localSettings"}]"#,
            with: #""behavior":"allow","destination":"localSettings"},{"type":"addRules","rules":[{"toolName":"Bash","ruleContent":"sudo:*"}],"behavior":"allow","destination":"localSettings"}]"#
        ))

        #expect(ask.suggestions.count == 2)
        #expect(ask.allowSuggestion == nil)
        #expect(!ask.canWiden)
    }

    static let companionRuleAsk = """
    {"type":"control_request","request_id":"b54b23b7-618d-431a-a967-bfd916f2609d",\
    "request":{"subtype":"can_use_tool","tool_name":"Bash","display_name":"Bash",\
    "input":{"command":"gh pr diff 61 > /tmp/pr61.diff && wc -l /tmp/pr61.diff && gh pr checks 61 2>&1 | head -30",\
    "description":"Get PR diff, line count, and check status"},\
    "description":"Get PR diff, line count, and check status",\
    "permission_suggestions":[{"type":"addRules","rules":[{"toolName":"Bash",\
    "ruleContent":"gh pr *"}],"behavior":"allow","destination":"localSettings"},\
    {"type":"addRules","rules":[{"toolName":"Read","ruleContent":"//private/tmp/**"}],\
    "behavior":"allow","destination":"session"}],\
    "decision_reason_type":"subcommandResults",\
    "tool_use_id":"toolu_01E3b8UL6KnXrx6828bX5NR1"}}
    """

    @Test("a companion Read rule does not cost the ask its button")
    func companionRuleKeepsTheButton() {
        let ask = Self.ask(Self.companionRuleAsk)

        #expect(ask.suggestions.count == 2)
        #expect(ask.rules == [PermissionRule(toolName: "Bash", ruleContent: "gh pr *")])
        #expect(ask.ruleText == "Bash(gh pr *)")
        #expect(ask.canWiden)
    }

    @Test("the companion rule is never sent back")
    func companionRuleIsNotEchoed() throws {
        let ask = Self.ask(Self.companionRuleAsk)
        let answer = try PermissionAnswer.encode(ask: ask, decision: .allow(scope: .session))
        let sent = Self.object(answer)["response"]?["response"]?["updatedPermissions"]

        #expect(sent?.arrayValue?.count == 1)
        #expect(sent?[0]?["rules"]?[0]?["toolName"]?.stringValue == "Bash")
        #expect(sent?[0]?["destination"]?.stringValue == "session")
        #expect(!answer.contains("//private/tmp/**"), "the Read companion went out with the grant")
    }

    @Test("a deny suggestion is never offered as an allow")
    func denySuggestionIsNotAnAllow() {
        let ask = Self.ask(Self.realAsk.replacingOccurrences(
            of: #""behavior":"allow""#,
            with: #""behavior":"deny""#
        ))

        #expect(ask.suggestions.count == 1)
        #expect(ask.allowSuggestion == nil)
    }

    @Test("a control request Unified Dev has no business answering stays unknown")
    func otherControlSubtype() {
        let line = #"{"type":"control_request","request_id":"x","request":{"subtype":"initialize"}}"#

        guard case .unknown = AgentEvent.decode(line: line) else {
            Issue.record("an unrelated control request was read as a permission ask")
            return
        }
    }

    @Test("the CLI answering Unified Dev is not a question")
    func controlResponseIsNotAnAsk() {
        let line = #"{"type":"control_response","response":{"subtype":"success","request_id":"x","response":{}}}"#

        guard case .unknown = AgentEvent.decode(line: line) else {
            Issue.record("a control response was read as a permission ask")
            return
        }
    }

    @Test("terminal colour codes never reach a row")
    func stripsEscapes() {
        let ask = Self.ask(Self.realAsk.replacingOccurrences(
            of: #""decision_reason":"This command requires approval""#,
            with: #""decision_reason":"\u001b[31mThis command requires approval\u001b[0m""#
        ))

        #expect(ask.reason == "This command requires approval")
    }

    @Test("allow once sends the input back and grants nothing")
    func allowOnce() throws {
        let ask = Self.ask()
        let answer = try PermissionAnswer.encode(ask: ask, decision: .allow(scope: .once))
        let json = Self.object(answer)

        #expect(json["type"]?.stringValue == "control_response")
        #expect(json["response"]?["subtype"]?.stringValue == "success")
        #expect(json["response"]?["request_id"]?.stringValue == ask.requestID)

        let body = json["response"]?["response"]
        #expect(body?["behavior"]?.stringValue == "allow")
        #expect(body?["updatedInput"] == ask.input)
        #expect(body?["updatedPermissions"] == nil)
    }

    @Test("a wider allow sends the CLI its own suggestion back, aimed at the session")
    func allowForSession() throws {
        let ask = Self.ask()
        let answer = try PermissionAnswer.encode(ask: ask, decision: .allow(scope: .session))
        let sent = Self.object(answer)["response"]?["response"]?["updatedPermissions"]?[0]

        #expect(sent?["type"]?.stringValue == "addRules")
        #expect(sent?["behavior"]?.stringValue == "allow")
        #expect(sent?["destination"]?.stringValue == "session")
        #expect(sent?["rules"] == ask.allowSuggestion?.raw["rules"])
    }

    @Test("project scope writes no settings file")
    func projectScopeTouchesNoFile() throws {
        let ask = Self.ask()
        let answer = try PermissionAnswer.encode(ask: ask, decision: .allow(scope: .project))
        let sent = Self.object(answer)["response"]?["response"]?["updatedPermissions"]?[0]

        #expect(sent?["destination"]?.stringValue == "session")
        for destination in ["localSettings", "projectSettings", "userSettings"] {
            #expect(!answer.contains(destination), "\(destination) would have written a file")
        }
    }

    @Test("a deny carries the sentence and does not end the turn by default")
    func deny() throws {
        let ask = Self.ask()
        let answer = try PermissionAnswer.encode(
            ask: ask,
            decision: .deny(message: "Not this one. Carry on with the rest.", endsTurn: false)
        )
        let body = Self.object(answer)["response"]?["response"]

        #expect(body?["behavior"]?.stringValue == "deny")
        #expect(body?["message"]?.stringValue == "Not this one. Carry on with the rest.")
        #expect(body?["interrupt"]?.boolValue == false)
        #expect(body?["updatedInput"] == nil)
    }

    @Test("deny and stop sets interrupt")
    func denyAndStop() throws {
        let ask = Self.ask()
        let answer = try PermissionAnswer.encode(ask: ask, decision: .deny(message: "No.", endsTurn: true))

        #expect(Self.object(answer)["response"]?["response"]?["interrupt"]?.boolValue == true)
    }

    @Test("an empty deny still says something useful to the model")
    func emptyDeny() throws {
        let ask = Self.ask()
        let answer = try PermissionAnswer.encode(ask: ask, decision: .deny(message: "   ", endsTurn: false))

        #expect(Self.object(answer)["response"]?["response"]?["message"]?.stringValue
            == PermissionDecision.defaultDenyMessage)
    }

    @Test("the answer is one line, because the wire is line delimited")
    func answersAreSingleLines() throws {
        let ask = Self.ask()
        let decisions: [PermissionDecision] = [
            .allow(scope: .once),
            .allow(scope: .session),
            .allow(scope: .project),
            .deny(message: "no\nreally\nno", endsTurn: false),
        ]

        for decision in decisions {
            let answer = try PermissionAnswer.encode(ask: ask, decision: decision)
            #expect(!answer.contains("\n"), "\(decision) encoded to more than one line")
        }
    }

    @Test("every scope says what it costs before it is pressed")
    func scopeCopy() {
        for scope in PermissionScope.allCases {
            #expect(!scope.consequence(rule: "Bash(bin/test:*)", project: "Unified Dev").isEmpty)
            #expect(!scope.buttonLabel.isEmpty)
        }

        #expect(PermissionScope.project.consequence(rule: "R", project: "Unified Dev").contains("Unified Dev"))
        #expect(PermissionScope.session.consequence(rule: "R", project: "Unified Dev").contains("R"))
    }
}
