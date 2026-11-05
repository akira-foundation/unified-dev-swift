import Testing
import Foundation
@testable import Core

@Suite("WorktreePath")
struct WorktreePathTests {
    @Test("a new worktree goes under its profile folder")
    func underProfile() {
        let root = URL(fileURLWithPath: "/w")
        #expect(
            WorktreePath.preferred(branch: "feat/x", project: "api", profileFolder: "debtges", under: root)
                == "/w/debtges/api/feat-x"
        )
    }
}
