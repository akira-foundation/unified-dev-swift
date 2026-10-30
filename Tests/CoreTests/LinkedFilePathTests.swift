import Testing
import Foundation
@testable import Core

@Suite("Linked file path")
struct LinkedFilePathTests {
    private static let worktree = "/Users/freek/unifieddev/workspaces/project/gulf"
    private static let checkout = "/Users/freek/dev/project"
    private static let spec = ".claude/worktrees/tycho/docs/specs/design.md"

    private static func resolve(
        _ path: String, existing: Set<String>, checkout: String? = checkout, changed: Set<String> = []
    ) -> String {
        LinkedFilePath.resolve(path, worktree: worktree, checkout: checkout, changed: changed) {
            existing.contains($0)
        }
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

    @Test("a file the worktree deleted stays on its diff instead of opening the checkout copy")
    func deletedInTheWorktree() {
        let resolved = Self.resolve(
            "./Sources/Old.swift",
            existing: [Self.checkout + "/Sources/Old.swift"],
            changed: ["Sources/Old.swift"]
        )
        #expect(resolved == "Sources/Old.swift")
    }

    @Test("a path neither has stays relative, so the pane says it is gone")
    func inNeither() {
        #expect(Self.resolve(Self.spec, existing: []) == Self.spec)
    }

    @Test("with no checkout known only the worktree is asked")
    func noCheckout() {
        var asked: [String] = []
        let resolved = LinkedFilePath.resolve(Self.spec, worktree: Self.worktree, checkout: nil) {
            asked.append($0)
            return $0 == Self.checkout + "/" + Self.spec
        }
        #expect(resolved == Self.spec)
        #expect(asked == [Self.worktree + "/" + Self.spec])
    }

    @Test("a workspace that is the checkout itself keeps the path relative")
    func workspaceIsTheCheckout() {
        let resolved = LinkedFilePath.resolve(
            Self.spec, worktree: Self.checkout, checkout: Self.checkout
        ) { $0 == Self.checkout + "/" + Self.spec }
        #expect(resolved == Self.spec)
    }

    @Test("an absolute path inside the worktree becomes relative to it")
    func absoluteInsideTheWorktree() {
        let resolved = Self.resolve(Self.worktree + "/Sources/App.swift", existing: [])
        #expect(resolved == "Sources/App.swift")
    }

    @Test("an absolute path elsewhere is left as it is and nothing is asked")
    func absoluteElsewhere() {
        var asked: [String] = []
        let resolved = LinkedFilePath.resolve(
            "/tmp/notes.md", worktree: Self.worktree, checkout: Self.checkout
        ) { asked.append($0); return false }
        #expect(resolved == "/tmp/notes.md")
        #expect(asked.isEmpty)
    }

    @Test("a leading ./ comes off whichever root answers", arguments: [
        (Set([LinkedFilePathTests.worktree + "/Tools/build.sh"]), "Tools/build.sh"),
        (Set([LinkedFilePathTests.checkout + "/Tools/build.sh"]), LinkedFilePathTests.checkout + "/Tools/build.sh"),
        (Set<String>(), "Tools/build.sh"),
    ])
    func dotSlash(existing: Set<String>, expected: String) {
        #expect(Self.resolve("./Tools/build.sh", existing: existing) == expected)
    }
}
