import Testing
import Foundation
@testable import Core

@Suite("Spend accounts state", .tags(.persistence))
struct SpendAccountsStateTests {
    private let account = SpendAccountLine(
        accountID: AgentAccountID("work"),
        name: "Work",
        provider: .claudeCode,
        spend: Spend(),
        sessions: []
    )

    private let input = SpendBoard.Input(days: [], window: .week)

    @Test func anEmptyReadSaysThereAreNoTurnsAndNothingElse() {
        #expect(SpendAccountsState.read([]).status == SpendBoard.emptyLine)
    }

    @Test func aReadWithLinesHasNothingToSayAndExposesTheLines() {
        let state = SpendAccountsState.read([account])
        #expect(state.status == nil)
        #expect(state.lines == [account])
    }

    @Test func anUnreadScreenDoesNotClaimThereAreNoTurns() {
        let status = SpendAccountsState.notRead.status
        #expect(status == SpendLines.accountsNotRead)
        #expect(status != SpendBoard.emptyLine)
        #expect(SpendAccountsState.notRead.lines.isEmpty)
    }

    @Test func aFailedReadSaysSoAndDiffersFromBothOtherStates() {
        let status = SpendAccountsState.failed.status
        #expect(status == SpendLines.accountsFailed)
        #expect(status != SpendBoard.emptyLine)
        #expect(status != SpendLines.accountsNotRead)
    }

    @Test func aReadableStoreGivesAReadState() async throws {
        let store = try makeTestStore("accounts-state")
        let state = await SpendBoard.accountsState(input, reading: store, defaults: [])
        #expect(state == .read([]))
    }

    @Test func aStoreThatCannotListItsAccountsGivesAFailedStateAndNotAnEmptyOne() async throws {
        let store = try makeTestStore("accounts-state")
        let other = try SQLiteDatabase(path: store.path)
        _ = try other.run("DROP TABLE agent_accounts")

        let state = await SpendBoard.accountsState(input, reading: store, defaults: [])

        #expect(state == .failed)
    }
}
