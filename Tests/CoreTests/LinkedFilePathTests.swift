import Testing
import Foundation
@testable import Core

@Suite("Linked file path")
struct LinkedFilePathTests {
    private static let worktree = "/Users/freek/unifieddev/workspaces/project/gulf"
    private static let checkout = "/Users/freek/dev/project"
    private static let spec = ".claude/worktrees/tycho/docs/specs/design.md"

    private static func resolve(_ path: String, existing: Set<String>, checkout: String? = checkout) -> String {
        LinkedFilePath.resolve(path, worktree: worktree, checkout: checkout) { existing.contains($0) }
    }

    @Test("a path the worktree has stays relative to it")
    func inTheWorktree() {
        let resolved = Self.resolve("Sources/App.swift", existing: [Self.worktree + "/Sources/App.swift"])
        #expect(resolved == "Sources/App.swift")
    }

    @Test("a path only the project checkout has opens through its absolute path")
    func onlyInTheCheckout() {
        let resolved = Self.resolve(Self.spec, existing: [Self.checkout + "/" + Self.spec])
        #expect(resolved == Self.checkout + "/" + Self.spec)
    }

    @Test("a path both have opens the worktree copy")
    func inBoth() {
        let resolved = Self.resolve(
            "README.md", existing: [Self.worktree + "/README.md", Self.checkout + "/README.md"]
        )
        #expect(resolved == "README.md")
    }

    @Test("a path neither has stays relative, so the pane says it is gone")
    func inNeither() {
        #expect(Self.resolve(Self.spec, existing: []) == Self.spec)
    }

    @Test("with no checkout known only the worktree is asked")
    func noCheckout() {
        let resolved = Self.resolve(Self.spec, existing: [Self.checkout + "/" + Self.spec], checkout: nil)
        #expect(resolved == Self.spec)
    }

    @Test("a workspace that is the checkout itself keeps the path relative")
    func workspaceIsTheCheckout() {
        let resolved = LinkedFilePath.resolve(
            Self.spec, worktree: Self.checkout, checkout: Self.checkout
        ) { $0 == Self.checkout + "/" + Self.spec }
        #expect(resolved == Self.spec)
    }

    @Test("an absolute path is left as it is and nothing is asked")
    func absolute() {
        var asked: [String] = []
        let resolved = LinkedFilePath.resolve(
            "/tmp/notes.md", worktree: Self.worktree, checkout: Self.checkout
        ) { asked.append($0); return false }
        #expect(resolved == "/tmp/notes.md")
        #expect(asked.isEmpty)
    }

    @Test("a leading ./ is read against both roots")
    func dotSlash() {
        let resolved = Self.resolve("./" + Self.spec, existing: [Self.checkout + "/" + Self.spec])
        #expect(resolved == Self.checkout + "/" + Self.spec)
    }
}
