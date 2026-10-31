import Testing
@testable import Core

@Suite("The notice for a branch that kept its name")
struct BranchKeptNoticeTests {
    @Test("a surprise names the branch in the title and gives the reason as a sentence")
    func surprise() throws {
        let notice = try #require(BranchKeptNotice.make(
            branch: "freekmurze/iyo-sea", refusal: .nameTaken("freekmurze/fade-feel")
        ))
        #expect(notice.title == "The branch is still freekmurze/iyo-sea")
        #expect(notice.reason.map(\.text).joined() == "freekmurze/fade-feel is already taken by another branch.")
        #expect(notice.reason.filter(\.isMachine).map(\.text) == ["freekmurze/fade-feel"])
    }

    @Test("the reason opens with a capital")
    func capitalised() throws {
        let notice = try #require(BranchKeptNotice.make(branch: "iyo-sea", refusal: .gitRefused("locked")))
        #expect(notice.reason.map(\.text).joined() == "Git refused to rename it: locked.")
    }

    @Test(
        "a refusal the user expected raises nothing",
        arguments: [
            BranchRenameRefusal.alreadyNamed, .noValidName, .hasCommits(91), .pushed, .hasPullRequest,
        ]
    )
    func quiet(refusal: BranchRenameRefusal) {
        #expect(BranchKeptNotice.make(branch: "aegean-sea", refusal: refusal) == nil)
    }
}
