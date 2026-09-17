import Testing
@testable import Core

@Suite("Pane number argument")
struct PaneNumberArgumentTests {
    @Test(
        "a pane number is a whole number from one, or nothing at all",
        arguments: [PaneNumberArgument.browser, .terminal, .tab]
    )
    func theRuleIsOneRule(argument: PaneNumberArgument) {
        #expect((try? argument.parse(nil).get()) == .some(nil))
        #expect((try? argument.parse(.null).get()) == .some(nil))
        #expect((try? argument.parse(.integer(1)).get()) == 1)
        #expect((try? argument.parse(.integer(7)).get()) == 7)

        for bad in [JSONValue.integer(0), .integer(-1), .number(1.5), .number(2.0), .string("1"),
                    .bool(true), .array([]), .object([:])] {
            guard case .failure = argument.parse(bad) else {
                Issue.record("\(argument.name) accepted \(bad)")
                return
            }
        }
    }

    @Test(
        "every refusal names its own argument and what prints its numbers",
        arguments: [PaneNumberArgument.browser, .terminal, .tab]
    )
    func everyRefusalIsSpecific(argument: PaneNumberArgument) {
        guard case .failure(let outOfRange) = argument.parse(.integer(0)),
              case .failure(let notANumber) = argument.parse(.string("first"))
        else {
            Issue.record("\(argument.name) did not refuse")
            return
        }
        for refusal in [outOfRange, notANumber] {
            #expect(refusal.sentence.contains("'\(argument.name)'"))
        }
        #expect(outOfRange.sentence.contains("counting from 1"))
        #expect(notANumber.sentence.contains(argument.printedBy))
    }

    @Test("the wording each family had is the wording it still has")
    func theWordingIsUnchanged() {
        guard case .failure(let browser) = PaneNumberArgument.browser.parse(.integer(0)),
              case .failure(let terminal) = PaneNumberArgument.terminal.parse(.string("1")),
              case .failure(let tab) = PaneNumberArgument.tab.parse(.string("notes"))
        else {
            Issue.record("expected three refusals")
            return
        }
        #expect(browser.sentence == "'browser' is the number pane_list gives a browser, counting "
            + "from 1. 0 is not one of them.")
        #expect(terminal.sentence == "'terminal' is a whole number, as pane_list prints it. Leave "
            + "it out when only one terminal is open, and call pane_list first when there is more "
            + "than one.")
        #expect(tab.sentence == "'tab' is a whole number, as workspace_tabs prints it. Call "
            + "workspace_tabs first and pass one of the numbers it gives.")
    }

    @Test("the tab tool reads its number through the shared rule")
    func theTabToolUsesIt() {
        guard case .failure(let refusal) = WorkspaceTabChoice.parse(
            number: .number(1.5), title: nil
        ) else {
            Issue.record("expected a refusal")
            return
        }
        #expect(refusal.sentence.contains("'tab' is a whole number"))

        #expect((try? WorkspaceTabChoice.parse(number: .integer(2), title: nil).get()) == .number(2))
    }
}
