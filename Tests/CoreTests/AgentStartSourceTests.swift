import CryptoKit
import Foundation
import Testing
@testable import Core

@Suite("workspace_start: which branch")
struct AgentStartSourceTests {
    @Test("a call that names neither gets what it has always got")
    func silenceIsANewBranch() {
        #expect(AgentStartRequest.read(baseBranch: nil, existingBranch: nil) == .newBranch(from: nil))
    }

    @Test("each argument names one of the sheet's two tabs")
    func eachArgumentNamesATab() {
        #expect(
            AgentStartRequest.read(baseBranch: "develop", existingBranch: nil)
                == .newBranch(from: "develop")
        )
        #expect(
            AgentStartRequest.read(baseBranch: nil, existingBranch: "freek/figma")
                == .existingBranch("freek/figma")
        )
        #expect(
            AgentStartRequest.read(
                baseBranch: nil, existingBranch: nil, pullRequest: "#66"
            ) == .pullRequest("#66")
        )
    }

    @Test("naming both is refused, and the refusal says what each one does")
    func bothIsRefused() {
        guard case .refused(let sentence) = AgentStartRequest.read(
            baseBranch: "main", existingBranch: "freek/figma"
        ) else {
            Issue.record("naming both should be refused")
            return
        }

        #expect(sentence.contains("'main'"))
        #expect(sentence.contains("'freek/figma'"))
        #expect(sentence.contains("base_branch"))
        #expect(sentence.contains("existing_branch"))
    }

    private let branches = [
        ExistingBranch(name: "freek/figma", isLocal: true),
        ExistingBranch(name: "main", isLocal: true),
        ExistingBranch(name: "release/3.0", isLocal: false),
    ]

    @Test("a branch that is there, local or only on the remote, is found")
    func found() {
        #expect(
            AgentStartBranch.find("freek/figma", among: branches, project: "ember")
                == .found(branches[0])
        )
        #expect(
            AgentStartBranch.find("release/3.0", among: branches, project: "ember")
                == .found(branches[2])
        )
    }

    @Test("the name git prints for a remote branch finds the same branch")
    func remotePrefixIsStripped() {
        #expect(
            AgentStartBranch.find("origin/release/3.0", among: branches, project: "ember")
                == .found(branches[2])
        )
    }

    @Test("a branch that is not there is refused, and the refusal names what is")
    func unknownBranch() {
        guard case .refused(let sentence) = AgentStartBranch.find(
            "freek/figmaa", among: branches, project: "ember"
        ) else {
            Issue.record("an unknown branch should be refused")
            return
        }

        #expect(sentence.contains("'ember' has no branch called 'freek/figmaa'"))
        #expect(sentence.contains("'freek/figma'"))
        #expect(sentence.contains("'release/3.0'"))
        #expect(sentence.contains("existing_branch"))
    }

    @Test("a project with nothing to continue on says that rather than listing nothing")
    func noBranchesAtAll() {
        guard case .refused(let sentence) = AgentStartBranch.find(
            "main", among: [], project: "ember"
        ) else {
            Issue.record("an empty project should be refused")
            return
        }

        #expect(sentence.contains("no branches in the project 'ember'"))
        #expect(sentence.contains("no commits yet"))
    }

    @Test("a branch something else is already on is refused, and the way out is an argument")
    func heldBranch() {
        let held = [ExistingBranch(name: "freek/figma", isLocal: true, inUseBy: .workspace("Coral Sea"))]

        guard case .refused(let sentence) = AgentStartBranch.find(
            "freek/figma", among: held, project: "ember"
        ) else {
            Issue.record("a held branch should be refused")
            return
        }

        #expect(sentence.contains("Coral Sea"))
        #expect(sentence.contains("one worktree per branch"))
        #expect(sentence.contains("base_branch"))
        #expect(!sentence.contains("tab"))
    }

    @Test("the project's own checkout is named by its path, not called a workspace")
    func heldByTheProjectItself() {
        let held = [
            ExistingBranch(name: "main", isLocal: true, inUseBy: .projectCheckout(path: "/dev/ember")),
        ]

        guard case .refused(let sentence) = AgentStartBranch.find(
            "main", among: held, project: "ember"
        ) else {
            Issue.record("a held branch should be refused")
            return
        }

        #expect(sentence.contains("/dev/ember"))
        #expect(sentence.contains("the project itself is on"))
    }

    @Test("a new branch carries a base and no checkout")
    func newBranchSource() {
        let source = AgentStartSource.newBranch(from: "develop")

        #expect(source.tab == .newBranch)
        #expect(source.baseBranch == "develop")
        #expect(source.namedBranch == "develop")
        #expect(source.checkout == nil)
    }

    @Test("an existing branch carries a checkout and no base")
    func existingBranchSource() {
        let branch = ExistingBranch(name: "freek/figma", isLocal: true)
        let source = AgentStartSource.existingBranch(branch)

        #expect(source.tab == .existingBranch)
        #expect(source.baseBranch == nil)
        #expect(source.namedBranch == "freek/figma")
        #expect(source.checkout == .branch(branch))
    }

    @Test("a pull request carries its checkout and base")
    func pullRequestSource() {
        let request = PullRequestListing(
            number: 66,
            title: "Add name suffix",
            headRefName: "name-suffix",
            baseRefName: "main"
        )
        let source = AgentStartSource.pullRequest(request)

        #expect(source.tab == .existingBranch)
        #expect(source.baseBranch == nil)
        #expect(source.namedBranch == "name-suffix")
        #expect(source.checkout == .pullRequest(request))
    }

    @Test("a call that names no existing branch digests exactly as it did before there was one")
    func digestIsStableForOlderCalls() {
        let parent = WorkspaceID(rawValue: "w-parent")
        let order = AgentWorkspaceOrder(prompt: "Import the webhooks", source: .newBranch(from: "develop"))

        let material = [parent.rawValue, "Import the webhooks", "", "develop", ""]
            .joined(separator: "\u{0}")
        let expected = SHA256.hash(data: Data(material.utf8))
            .prefix(8).map { String(format: "%02x", $0) }.joined()

        #expect(order.spawnID(parentWorkspaceID: parent) == expected)
    }

    @Test("cutting from a branch and carrying it on are two different calls")
    func digestTellsTheTwoVerbsApart() {
        let parent = WorkspaceID(rawValue: "w-parent")
        let cut = AgentWorkspaceOrder(prompt: "look at it", source: .newBranch(from: "freek/figma"))
        let carryOn = AgentWorkspaceOrder(
            prompt: "look at it",
            source: .existingBranch(ExistingBranch(name: "freek/figma", isLocal: true))
        )

        #expect(cut.spawnID(parentWorkspaceID: parent) != carryOn.spawnID(parentWorkspaceID: parent))
    }
}
