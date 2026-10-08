import Foundation
import Testing
@testable import Core

@Suite("Which press cycles the centre tabs")
struct CentreTabCycleTargetTests {
    private let mainSceneID = "main"

    private func cycles(
        role: WindowDismissal.Role = .workspace,
        identifier: String? = "main",
        isSheet: Bool = false,
        isPanel: Bool = false,
        isEditingText: Bool = false,
        isEditingThePrompt: Bool = false
    ) -> Bool {
        CentreTabCycleTarget.cycles(
            CentreTabCycleTarget.Press(
                role: role,
                identifier: identifier,
                isSheet: isSheet,
                isPanel: isPanel,
                isEditingText: isEditingText,
                isEditingThePrompt: isEditingThePrompt
            ),
            mainSceneID: mainSceneID
        )
    }

    @Test("a press in the window the main scene was given cycles")
    func theMainSceneCycles() {
        #expect(cycles())
        #expect(cycles(identifier: "main-AppWindow-1"))
    }

    @Test("a window of another role never cycles, however it is named", arguments: [
        WindowDismissal.Role.utility, .reading
    ])
    func anotherRoleDoesNot(role: WindowDismissal.Role) {
        #expect(!cycles(role: role))
        #expect(!cycles(role: role, identifier: "main"))
    }

    @Test("a sheet and a panel keep the key, even over the main scene")
    func aSheetAndAPanelDoNot() {
        #expect(!cycles(isSheet: true))
        #expect(!cycles(isPanel: true))
    }

    @Test("a window with no identifier does not cycle")
    func anUnnamedWindowDoesNot() {
        #expect(!cycles(identifier: nil))
    }

    @Test("another scene does not cycle, and neither does one that merely contains the name", arguments: [
        "settings", "repo-settings", "oceans", "", "domain", "domain-settings", "remains"
    ])
    func anotherSceneDoesNot(identifier: String) {
        #expect(!cycles(identifier: identifier))
    }

    @Test("a field the owner is typing in keeps the key, because losing it loses what they wrote")
    func anEditedFieldKeepsIt() {
        #expect(!cycles(isEditingText: true))
    }

    @Test("the prompt is the one field that still cycles, by the owner's decision")
    func thePromptStillCycles() {
        #expect(cycles(isEditingText: true, isEditingThePrompt: true))
    }

    @Test("a view that is not a field, which is what the terminal is, loses the key")
    func theTerminalLosesIt() {
        #expect(cycles(isEditingText: false, isEditingThePrompt: false))
    }
}
