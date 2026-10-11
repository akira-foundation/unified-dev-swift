import Testing
import Foundation
@testable import Core

private let gate = "UD_LOCAL_TRANSCRIPTS"

private func money(_ amount: Double) -> String {
    String(format: "%.2f", amount)
}

private func millions(_ tokens: Int) -> String {
    String(format: "%.2f M", Double(tokens) / 1_000_000)
}

@Suite("Spend on this Mac", .enabled(if: ProcessInfo.processInfo.environment[gate] == "1"))
struct SpendOnThisMacTests {
    @Test("the first build and a refresh are both measured on the real transcripts")
    func measureBuildAndRefresh() async throws {
        let store = try makeTestStore("spend-this-mac")
        let indexer = SpendIndexer(store: store)

        let buildStart = ContinuousClock.now
        let build = try await indexer.refresh()
        let buildTook = ContinuousClock.now - buildStart

        let refreshStart = ContinuousClock.now
        let refresh = try await indexer.refresh()
        let refreshTook = ContinuousClock.now - refreshStart

        let gigabytes = Double(build.bytesRead) / 1_073_741_824
        print("""

        First build: \(build.filesRead) files, \(String(format: "%.2f", gigabytes)) GB, \
        \(build.records) turns, \(buildTook), abandoned \(build.abandonedLines) lines
        Refresh: \(refresh.filesRead) files, \(refresh.bytesRead) bytes, \(refreshTook)
        """)

        #expect(build.finished)
        #expect(build.records > 0)
        #expect(refresh.bytesRead < build.bytesRead)

        let board = SpendBoard.make(SpendBoard.Input(
            days: try await store.spendDays(since: Date().addingTimeInterval(-31 * 86_400)),
            window: .week
        ))
        print("Seven days: \(money(board.total.cost.total)) over \(millions(board.total.usage.total))")
        for column in board.columns {
            print("""
              \(column.column.label): \(millions(column.tokens)) \
              (\(String(format: "%.1f", column.tokenShare * 100))% of tokens), \
              \(money(column.cost)) (\(String(format: "%.1f", column.costShare * 100))% of cost)
            """)
        }
        for provider in board.providers {
            print("  \(provider.kind.label): \(money(provider.spend.cost.total)) over \(provider.turns) turns")
        }
        print("Cache saving: \(money(board.total.cost.saved))")
        print("Unpriced tokens: \(millions(board.total.unpriced.total))")
    }
}
