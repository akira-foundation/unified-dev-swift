import Testing
@testable import Core

@Suite("The window the welcome window centres on")
struct WelcomeAnchorTests {
    @Test("A visible workspace window is the one to centre on")
    func workspace() {
        #expect(WelcomeAnchor.canAnchor(WelcomeAnchorCandidate(role: .workspace, isVisible: true)))
    }

    @Test("A window nobody can see anchors nothing")
    func hidden() {
        #expect(!WelcomeAnchor.canAnchor(WelcomeAnchorCandidate(role: .workspace, isVisible: false)))
    }

    @Test("Utility and reading windows are not the main window", arguments: [
        WindowDismissal.Role.utility, .reading,
    ])
    func otherRoles(role: WindowDismissal.Role) {
        #expect(!WelcomeAnchor.canAnchor(WelcomeAnchorCandidate(role: role, isVisible: true)))
    }

    @Test("A window with no role of its own reads as a workspace, so the shape decides")
    func unmarkedShapes() {
        let sheet = WelcomeAnchorCandidate(role: .workspace, isVisible: true, isSheet: true)
        let panel = WelcomeAnchorCandidate(role: .workspace, isVisible: true, isPanel: true)
        let child = WelcomeAnchorCandidate(role: .workspace, isVisible: true, hasParent: true)
        #expect(!WelcomeAnchor.canAnchor(sheet))
        #expect(!WelcomeAnchor.canAnchor(panel))
        #expect(!WelcomeAnchor.canAnchor(child))
    }
}
