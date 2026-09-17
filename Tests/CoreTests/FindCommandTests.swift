import Testing
@testable import Core

@Suite("What Cmd+F finds")
struct FindCommandTests {
    @Test("a pane that can find keeps the keystroke")
    func findsInPlace() {
        #expect(FindCommand.find(canFindInPlace: true, hasProjects: true) == .findInPlace)
        #expect(FindCommand.find(canFindInPlace: true, hasProjects: false) == .findInPlace)
    }

    @Test("a pane that cannot find falls through to the workspace search")
    func fallsThroughToSearch() {
        #expect(FindCommand.find(canFindInPlace: false, hasProjects: true) == .workspaceSearch)
    }

    @Test("with no projects there is nothing to find anywhere")
    func nothingToFind() {
        #expect(FindCommand.find(canFindInPlace: false, hasProjects: false) == nil)
    }

    @Test("Cmd+G only ever means the find in front")
    func stepping() {
        #expect(FindCommand.step(canFindInPlace: true) == .findInPlace)
        #expect(FindCommand.step(canFindInPlace: false) == nil)
    }
}
