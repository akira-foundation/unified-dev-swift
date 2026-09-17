import Testing
@testable import Core

@Suite("Which base the create window fetches ahead of Create")
struct BaseBranchPrefetchTests {
    @Test("a project and a base to cut from is a fetch to start")
    func projectAndBase() {
        #expect(
            BaseBranchPrefetch.target(repoPath: "/repo", baseBranch: "main", opensCheckout: false)
                == BaseBranchPrefetch(repoPath: "/repo", baseBranch: "main")
        )
    }

    @Test("no project, no base yet, or a checkout fetches nothing")
    func nothingToCut() {
        #expect(BaseBranchPrefetch.target(repoPath: nil, baseBranch: "main", opensCheckout: false) == nil)
        #expect(BaseBranchPrefetch.target(repoPath: "/repo", baseBranch: "", opensCheckout: false) == nil)
        #expect(BaseBranchPrefetch.target(repoPath: "/repo", baseBranch: "main", opensCheckout: true) == nil)
    }

    @Test("choosing another base or another project is another fetch")
    func keyedOnProjectAndBase() {
        let main = BaseBranchPrefetch.target(repoPath: "/repo", baseBranch: "main", opensCheckout: false)
        let develop = BaseBranchPrefetch.target(repoPath: "/repo", baseBranch: "develop", opensCheckout: false)
        let elsewhere = BaseBranchPrefetch.target(repoPath: "/other", baseBranch: "main", opensCheckout: false)
        #expect(main != develop)
        #expect(main != elsewhere)
    }
}
