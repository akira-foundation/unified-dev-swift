import Testing
import Foundation
@testable import Core

@Suite("Linked file path")
struct LinkedFilePathTests {
    private static let worktree = "/Users/freek/unifieddev/workspaces/project/gulf"
    private static let checkout = "/Users/freek/dev/project"
    private static let spec = ".claude/worktrees/tycho/docs/specs/design.md"

    private static func resolve(
        _ path: String, existing: Set<String>, checkout: String? = checkout
    ) -> LinkedFilePath {
        LinkedFilePath.resolve(path, worktree: worktree, checkout: checkout) { existing.contains($0) }
    }

    @Test("a path the worktree has stays relative to it")
    func inTheWorktree() {
        let resolved = Self.resolve("Sources/App.swift", existing: [Self.worktree + "/Sources/App.swift"])
        #expect(resolved == .resolved("Sources/App.swift"))
    }

    @Test("a path only the project checkout has is a candidate there")
    func onlyInTheCheckout() {
        let resolved = Self.resolve(Self.spec, existing: [Self.checkout + "/" + Self.spec])
        #expect(resolved == .onlyInCheckout(relative: Self.spec, checkout: Self.checkout))
    }

    @Test("a path both have opens the worktree copy")
    func inBoth() {
        let resolved = Self.resolve(
            "README.md", existing: [Self.worktree + "/README.md", Self.checkout + "/README.md"]
        )
        #expect(resolved == .resolved("README.md"))
    }

    @Test("a path neither has stays relative, so the pane says it is gone")
    func inNeither() {
        #expect(Self.resolve(Self.spec, existing: []) == .resolved(Self.spec))
    }

    @Test("with no checkout known only the worktree is asked")
    func noCheckout() {
        var asked: [String] = []
        let resolved = LinkedFilePath.resolve("./" + Self.spec, worktree: Self.worktree, checkout: nil) {
            asked.append($0)
            return $0 == Self.checkout + "/" + Self.spec
        }
        #expect(resolved == .resolved(Self.spec))
        #expect(asked == [Self.worktree + "/" + Self.spec])
    }

    @Test("a workspace that is the checkout itself keeps the path relative")
    func workspaceIsTheCheckout() {
        let resolved = LinkedFilePath.resolve(
            Self.spec, worktree: Self.checkout, checkout: Self.checkout
        ) { $0 == Self.checkout + "/" + Self.spec }
        #expect(resolved == .resolved(Self.spec))
    }

    @Test("an absolute path inside the worktree becomes relative to it")
    func absoluteInsideTheWorktree() {
        let resolved = Self.resolve(Self.worktree + "/Sources/App.swift", existing: [])
        #expect(resolved == .resolved("Sources/App.swift"))
    }

    @Test("an absolute path elsewhere is left as it is and nothing is asked")
    func absoluteElsewhere() {
        var asked: [String] = []
        let resolved = LinkedFilePath.resolve(
            "/tmp/notes.md", worktree: Self.worktree, checkout: Self.checkout
        ) { asked.append($0); return false }
        #expect(resolved == .resolved("/tmp/notes.md"))
        #expect(asked.isEmpty)
    }

    @Test("a leading ./ comes off whichever root answers", arguments: [
        (Set([LinkedFilePathTests.worktree + "/Tools/build.sh"]), LinkedFilePath.resolved("Tools/build.sh")),
        (
            Set([LinkedFilePathTests.checkout + "/Tools/build.sh"]),
            LinkedFilePath.onlyInCheckout(relative: "Tools/build.sh", checkout: LinkedFilePathTests.checkout)
        ),
        (Set<String>(), LinkedFilePath.resolved("Tools/build.sh")),
    ])
    func dotSlash(existing: Set<String>, expected: LinkedFilePath) {
        #expect(Self.resolve("./Tools/build.sh", existing: existing) == expected)
    }

    @Test("a checkout file git does not track opens through its absolute path")
    func untrackedInCheckout() {
        let candidate = LinkedFilePath.onlyInCheckout(relative: Self.spec, checkout: Self.checkout)
        #expect(candidate.path(trackedInCheckout: false) == Self.checkout + "/" + Self.spec)
    }

    @Test("a checkout file git tracks stays relative, so a file the worktree deleted is not shown stale")
    func trackedInCheckout() {
        let candidate = LinkedFilePath.onlyInCheckout(relative: "Sources/Old.swift", checkout: Self.checkout)
        #expect(candidate.path(trackedInCheckout: true) == "Sources/Old.swift")
    }

    @Test("a resolved path ignores what the checkout tracks", arguments: [true, false])
    func resolvedIgnoresTracking(tracked: Bool) {
        #expect(LinkedFilePath.resolved("README.md").path(trackedInCheckout: tracked) == "README.md")
    }

    @Test("in a real repository, an ignored spec opens from the checkout and a tracked file does not")
    func settledAgainstGit() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("linked-file-path-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let worktree = root.appendingPathComponent("worktree").path
        let checkout = root.appendingPathComponent("checkout").path
        try FileManager.default.createDirectory(atPath: worktree, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: checkout + "/docs", withIntermediateDirectories: true)
        try Data("docs/\n".utf8).write(to: URL(fileURLWithPath: checkout + "/.gitignore"))
        try Data().write(to: URL(fileURLWithPath: checkout + "/docs/spec.md"))
        try Data().write(to: URL(fileURLWithPath: checkout + "/Old.swift"))
        _ = try await Shell.run("git", ["init", "-q"], cwd: checkout)
        _ = try await Shell.run("git", ["add", "Old.swift", ".gitignore"], cwd: checkout)

        let spec = await LinkedFilePath.resolve("docs/spec.md", worktree: worktree, checkout: checkout).settled()
        let old = await LinkedFilePath.resolve("Old.swift", worktree: worktree, checkout: checkout).settled()
        #expect(spec == checkout + "/docs/spec.md")
        #expect(old == "Old.swift")
    }
}
