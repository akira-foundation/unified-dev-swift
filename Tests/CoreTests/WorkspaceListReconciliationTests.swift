import Foundation
import Testing
@testable import Core

@Suite("Workspace list reconciliation")
struct WorkspaceListReconciliationTests {
    private static let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)

    private func workspace(
        _ id: String,
        name: String? = nil,
        additions: Int = 0,
        setupState: SetupState = .succeeded
    ) -> Workspace {
        Workspace(
            id: WorkspaceID(id),
            repoID: RepoID("repo"),
            name: name ?? id,
            branch: "feature/\(id)",
            path: "/tmp/\(id)",
            baseBranch: "main",
            setupState: setupState,
            createdAt: Self.fixedDate,
            lastActivityAt: Self.fixedDate,
            additions: additions
        )
    }

    private func reconciled(
        held: [Workspace], snapshot: [Workspace], fresh: [Workspace]
    ) -> [Workspace] {
        WorkspaceListReconciliation.reconciled(held: held, snapshot: snapshot, fresh: fresh)
    }

    @Test("an archive that has not reached the store yet is not undone")
    func archiveInFlightStaysHidden() {
        let alpha = workspace("alpha")
        let beta = workspace("beta")
        let gamma = workspace("gamma")

        let result = reconciled(
            held: [alpha, beta],
            snapshot: [alpha, beta, gamma],
            fresh: [alpha, beta, gamma]
        )

        #expect(result.map(\.id.rawValue) == ["alpha", "beta"])
    }

    @Test("two archives in quick succession both stay hidden")
    func twoArchivesStayHidden() {
        let alpha = workspace("alpha")
        let beta = workspace("beta")
        let gamma = workspace("gamma")

        let result = reconciled(
            held: [alpha],
            snapshot: [alpha, beta, gamma],
            fresh: [alpha, beta, gamma]
        )

        #expect(result.map(\.id.rawValue) == ["alpha"])
    }

    @Test("a restored row survives a refresh that read the store before it came back")
    func restoredRowSurvives() {
        let alpha = workspace("alpha")
        let gamma = workspace("gamma")

        let result = reconciled(
            held: [alpha, gamma],
            snapshot: [alpha],
            fresh: [alpha, gamma]
        )

        #expect(result.map(\.id.rawValue) == ["alpha", "gamma"])
    }

    @Test("a workspace created while the read was in flight is not dropped")
    func createdRowIsKept() {
        let alpha = workspace("alpha")
        let fresh = workspace("fresh")

        let result = reconciled(
            held: [alpha, fresh],
            snapshot: [alpha],
            fresh: [alpha]
        )

        #expect(result.map(\.id.rawValue) == ["alpha", "fresh"])
        #expect(result.last == fresh)
    }

    @Test("a rename made during the read is not written over")
    func renameSurvives() {
        let before = workspace("alpha", name: "Old name")
        let after = workspace("alpha", name: "New name")
        let stale = workspace("alpha", name: "Old name", additions: 42)

        let result = reconciled(held: [after], snapshot: [before], fresh: [stale])

        #expect(result.map(\.name) == ["New name"])
        #expect(result.map(\.additions) == [0])
    }

    @Test("a row nobody touched takes the store's version")
    func untouchedRowIsRefreshed() {
        let alpha = workspace("alpha")
        let beta = workspace("beta")
        let refreshedAlpha = workspace("alpha", additions: 120)
        let refreshedBeta = workspace("beta", additions: 3)

        let result = reconciled(
            held: [alpha, beta],
            snapshot: [alpha, beta],
            fresh: [refreshedAlpha, refreshedBeta]
        )

        #expect(result == [refreshedAlpha, refreshedBeta])
    }

    @Test("a setup that finished during the pass is picked up")
    func setupStateIsRefreshed() {
        let running = workspace("alpha", setupState: .running)
        let done = workspace("alpha", setupState: .succeeded)

        let result = reconciled(held: [running], snapshot: [running], fresh: [done])

        #expect(result.map(\.setupState) == [.succeeded])
    }

    @Test("an unchanged list takes the store's answer in full")
    func unchangedListTakesStore() {
        let alpha = workspace("alpha")
        let beta = workspace("beta")
        let fresh = [workspace("alpha", additions: 1), workspace("beta", additions: 2)]

        #expect(reconciled(held: [alpha, beta], snapshot: [alpha, beta], fresh: fresh) == fresh)
    }

    @Test("order comes from the list as it stands, not from the store")
    func orderComesFromHeld() {
        let alpha = workspace("alpha")
        let beta = workspace("beta")

        let result = reconciled(
            held: [beta, alpha],
            snapshot: [beta, alpha],
            fresh: [alpha, beta]
        )

        #expect(result.map(\.id.rawValue) == ["beta", "alpha"])
    }

    @Test("an empty list stays empty")
    func emptyStaysEmpty() {
        #expect(reconciled(held: [], snapshot: [], fresh: [workspace("alpha")]).isEmpty)
    }

    @Test("a reload does not put back a row whose archive is still running")
    func reloadKeepsArchivingRowHidden() {
        let alpha = workspace("alpha")
        let gamma = workspace("gamma")

        let result = WorkspaceListReconciliation.afterStoreReload(
            fresh: [alpha, gamma], archiving: [WorkspaceID("gamma")]
        )

        #expect(result.map(\.id.rawValue) == ["alpha"])
    }

    @Test("a reload brings back a row whose archive has stopped")
    func reloadRestoresAfterFailedArchive() {
        let alpha = workspace("alpha")
        let gamma = workspace("gamma")

        let result = WorkspaceListReconciliation.afterStoreReload(
            fresh: [alpha, gamma], archiving: []
        )

        #expect(result.map(\.id.rawValue) == ["alpha", "gamma"])
    }

    @Test("two archives running at once both stay out of a reload")
    func reloadKeepsBothArchivingRowsHidden() {
        let alpha = workspace("alpha")
        let beta = workspace("beta")
        let gamma = workspace("gamma")

        let result = WorkspaceListReconciliation.afterStoreReload(
            fresh: [alpha, beta, gamma], archiving: [WorkspaceID("beta"), WorkspaceID("gamma")]
        )

        #expect(result.map(\.id.rawValue) == ["alpha"])
    }

    @Test("a reload still adds a workspace the list has never seen")
    func reloadAddsRestoredWorkspace() {
        let alpha = workspace("alpha")
        let restored = workspace("restored")

        let result = WorkspaceListReconciliation.afterStoreReload(
            fresh: [alpha, restored], archiving: [WorkspaceID("gamma")]
        )

        #expect(result.map(\.id.rawValue) == ["alpha", "restored"])
    }
}
