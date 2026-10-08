import Foundation
import Testing
@testable import Core

@Suite("Which window the tab cycling key acts in")
struct CentreTabCycleWindowTests {
    private let mainSceneID = "main"

    private func cycles(
        role: WindowDismissal.Role = .workspace, identifier: String? = "main"
    ) -> Bool {
        CentreTabCycleWindow.cycles(
            role: role, identifier: identifier, mainSceneID: mainSceneID
        )
    }

    @Test("the window the main scene was given cycles")
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

    @Test("a window with no identifier does not cycle, which is what a sheet and a panel are")
    func anUnnamedWindowDoesNot() {
        #expect(!cycles(identifier: nil))
    }

    @Test("another scene of the same role does not cycle", arguments: [
        "settings", "repo-settings", "oceans", ""
    ])
    func anotherSceneDoesNot(identifier: String) {
        #expect(!cycles(identifier: identifier))
    }

    @Test("with no main scene named, nothing cycles")
    func noSceneNamedCyclesNothing() {
        #expect(!CentreTabCycleWindow.cycles(role: .workspace, identifier: "main", mainSceneID: ""))
    }
}
