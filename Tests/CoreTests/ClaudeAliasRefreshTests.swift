import Foundation
import Synchronization
import Testing
@testable import Core

private final class ManualClock: @unchecked Sendable {
    private let instant = Mutex(ContinuousClock.now)

    var now: ContinuousClock.Instant { instant.withLock { $0 } }
    func advance(by duration: Duration) { instant.withLock { $0 += duration } }
}

private final class InstalledVersion: @unchecked Sendable {
    private let state = Mutex<(version: String?, reads: Int)>((nil, 0))

    init(_ version: String?) { state.withLock { $0.version = version } }

    var reads: Int { state.withLock { $0.reads } }
    func change(to version: String?) { state.withLock { $0.version = version } }
    func read() -> String? {
        state.withLock { state in
            state.reads += 1
            return state.version
        }
    }
}

@Suite("When the aliases of Claude Code are asked again", .tags(.agentProtocol), .scratchDirectory)
struct ClaudeAliasRefreshTests {
    private let work = AgentAccountHome(
        provider: .claudeCode, id: AgentAccountID("work"),
        directory: URL(filePath: "/accounts/claudeCode/work"), isDefault: false
    )

    private func refresh(
        _ launches: ProbeLaunches,
        version: InstalledVersion,
        clock: ManualClock,
        answer: @escaping @Sendable (String) -> [String]
    ) -> ClaudeAliasRefresh {
        ClaudeAliasRefresh(
            probe: { _ in scriptedProbe(launches, timeout: .milliseconds(20), output: answer) },
            installedVersion: { _ in version.read() },
            now: { clock.now }
        )
    }

    @Test("one version of the CLI is probed once per account, and what it answered is kept for that account")
    func probesAVersionOnce() async throws {
        let store = try makeTestStore("refresh")
        let launches = ProbeLaunches()
        let clock = ManualClock()
        let refresh = refresh(launches, version: InstalledVersion("2.1.309"), clock: clock) { alias in
            [probeInitLine("claude-\(alias)-5-5")]
        }

        await refresh.refresh(account: work, in: store)
        clock.advance(by: ClaudeAliasRefresh.recheckInterval)
        await refresh.refresh(account: work, in: store)

        #expect(launches.launches.count == ClaudeModelCatalog.builtIn.count)
        #expect(await ClaudeResolvedModel.reported(account: work, in: store) == [
            "fable": "claude-fable-5-5", "opus": "claude-opus-5-5",
            "sonnet": "claude-sonnet-5-5", "haiku": "claude-haiku-5-5",
        ])
        #expect(await ClaudeResolvedModel.reported(account: nil, in: store).isEmpty)
    }

    @Test("a CLI updated while the app is open is probed again, and its answer replaces the old one")
    func probesANewVersion() async throws {
        let store = try makeTestStore("refresh")
        let launches = ProbeLaunches()
        let clock = ManualClock()
        let version = InstalledVersion("2.1.309")
        let answers = Mutex("5-1")
        let refresh = refresh(launches, version: version, clock: clock) { alias in
            [probeInitLine("claude-\(alias)-\(answers.withLock { $0 })")]
        }

        await refresh.refresh(account: work, in: store)
        version.change(to: "2.1.322")
        answers.withLock { $0 = "5-2" }
        clock.advance(by: ClaudeAliasRefresh.recheckInterval)
        await refresh.refresh(account: work, in: store)

        #expect(launches.launches.count == 2 * ClaudeModelCatalog.builtIn.count)
        #expect(await ClaudeResolvedModel.reported(account: work, in: store)["fable"] == "claude-fable-5-2")
    }

    @Test("the installed version is not read again within the interval")
    func readsTheVersionAtMostOncePerInterval() async throws {
        let store = try makeTestStore("refresh")
        let launches = ProbeLaunches()
        let version = InstalledVersion("2.1.309")
        let refresh = refresh(launches, version: version, clock: ManualClock()) { alias in
            [probeInitLine("claude-\(alias)-5-5")]
        }

        await refresh.refresh(account: work, in: store)
        version.change(to: "2.1.322")
        await refresh.refresh(account: work, in: store)

        #expect(version.reads == 1)
        #expect(launches.launches.count == ClaudeModelCatalog.builtIn.count)
    }

    @Test("an account whose probe answered nothing is asked again once the interval has passed", .timeLimit(.minutes(1)))
    func retriesAnAccountThatAnsweredNothing() async throws {
        let store = try makeTestStore("refresh")
        let launches = ProbeLaunches()
        let clock = ManualClock()
        let refresh = refresh(launches, version: InstalledVersion(nil), clock: clock) { _ in [] }

        await refresh.refresh(account: work, in: store)
        clock.advance(by: ClaudeAliasRefresh.recheckInterval)
        await refresh.refresh(account: work, in: store)

        #expect(launches.launches.count == 2 * ClaudeModelCatalog.builtIn.count)
        #expect(await ClaudeResolvedModel.reported(account: work, in: store).isEmpty)
    }
}
