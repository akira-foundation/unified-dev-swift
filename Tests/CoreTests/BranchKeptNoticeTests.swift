import Testing
@testable import Core

@Suite("The notice for a branch that kept its name")
struct BranchKeptNoticeTests {
    @Test("a surprise gives the reason as a sentence with the branch names set apart")
    func surprise() throws {
        let notice = try #require(BranchKeptNotice.make(refusal: .nameTaken("freekmurze/fade-feel")))
        #expect(notice.title == "The branch was not renamed")
        #expect(notice.reason.map(\.text).joined() == "freekmurze/fade-feel is already taken by another branch.")
        #expect(notice.reason.filter(\.isMachine).map(\.text) == ["freekmurze/fade-feel"])
    }

    @Test("the reason opens with a capital")
    func capitalised() throws {
        let notice = try #require(BranchKeptNotice.make(refusal: .detachedHead))
        #expect(notice.reason.map(\.text).joined() == "This worktree is not on a branch at all.")
    }

    @Test("a git refusal keeps the command it quotes set apart and ends on one full stop")
    func gitRefusal() throws {
        let message = "`git branch -m -- a b` exited 128: fatal: a branch named 'b' already exists."
        let notice = try #require(BranchKeptNotice.make(refusal: .gitRefused(message)))
        #expect(notice.reason.map(\.text).joined()
            == "Git refused to rename it: git branch -m -- a b exited 128: fatal: a branch named 'b' already exists.")
        #expect(notice.reason.filter(\.isMachine).map(\.text) == ["git branch -m -- a b"])
    }

    @Test(
        "a refusal the user expected raises nothing",
        arguments: [
            BranchRenameRefusal.alreadyNamed, .noValidName, .hasCommits(91), .pushed, .hasPullRequest,
        ]
    )
    func quiet(refusal: BranchRenameRefusal) {
        #expect(BranchKeptNotice.make(refusal: refusal) == nil)
    }
}
