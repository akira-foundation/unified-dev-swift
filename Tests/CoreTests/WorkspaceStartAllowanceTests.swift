import Testing
import Foundation
@testable import Core

@Suite("Workspace start allowance")
struct WorkspaceStartAllowanceTests {
    @Test("who asked decides which brake applies")
    func brakePerOrigin() {
        #expect(WorkspaceStartAllowance.of(.user) == .unlimited)
        #expect(
            WorkspaceStartAllowance
                .of(.agent(parentWorkspaceID: WorkspaceID("w1"), spawnToolUseID: "t1"))
                == .running(limit: WorkspaceStartAllowance.maximumChildren)
        )
        #expect(
            WorkspaceStartAllowance.of(.ownerClient(spawnToolUseID: "t1"))
                == .rate(
                    limit: WorkspaceStartAllowance.maximumOwnerStarts,
                    window: WorkspaceStartAllowance.ownerWindow
                )
        )
    }

    @Test("the owner's own hand is never refused, however many they have")
    func theSheetIsUncapped() {
        #expect(WorkspaceStartAllowance.unlimited.refusal(count: 400) == nil)
        #expect(!WorkspaceStartAllowance.unlimited.isExceeded(by: 400))
    }

    @Test("a ceiling refuses at the limit and not below it")
    func ceiling() {
        let allowance = WorkspaceStartAllowance.running(limit: 8)

        #expect(allowance.refusal(count: 7) == nil)
        #expect(allowance.refusal(count: 8)?.contains("which is Unified Dev's limit") == true)
        #expect(allowance.refusal(count: 9)?.contains("9 workspaces running") == true)
    }

    @Test("a rate refuses at the limit and not below it")
    func rate() {
        let allowance = WorkspaceStartAllowance.rate(limit: 6, window: 15 * 60)

        #expect(allowance.refusal(count: 5) == nil)
        #expect(allowance.refusal(count: 6)?.contains("in the last 15 minutes") == true)
    }

    @Test("the rate refusal says that waiting and retrying are both pointless")
    func theRateRefusalHeadsOffARetryLoop() throws {
        let sentence = try #require(
            WorkspaceStartAllowance.rate(limit: 6, window: 15 * 60).refusal(count: 6)
        )

        #expect(sentence.contains("do not retry and do not wait for it"))
        #expect(sentence.contains("nothing you can do here shortens"))
        #expect(!sentence.contains("/"))
    }
}
