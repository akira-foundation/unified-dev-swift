import SwiftUI
import Observation
import Core

@MainActor
@Observable
final class GitHubAvailability {
    static let shared = GitHubAvailability()

    enum State: Equatable {
        case unknown
        case ready
        case notInstalled
        case signedOut

        init(_ access: GitHubAccess) {
            switch access {
            case .ready: self = .ready
            case .notInstalled: self = .notInstalled
            case .signedOut: self = .signedOut
            }
        }

        var isUsable: Bool { self != .notInstalled && self != .signedOut }
    }

    private(set) var state: State = .unknown

    private static let negativeLifetime = Duration.seconds(120)

    private var probe: Task<State, Never>?
    private var answeredAt: ContinuousClock.Instant?

    func isReady() async -> Bool {
        await check() == .ready
    }

    @discardableResult
    func check(force: Bool = false) async -> State {
        if force {
            probe?.cancel()
            probe = nil
            answeredAt = nil
        } else {
            if state == .ready { return .ready }
            if let answeredAt, answeredAt.duration(to: .now) < Self.negativeLifetime,
               !state.isUsable {
                return state
            }
            if let probe { return await probe.value }
        }

        let task = Task { State(await GitHubBridge.access()) }
        probe = task
        let answer = await task.value
        guard probe == task else { return answer }
        probe = nil
        answeredAt = .now
        state = answer
        return answer
    }
}

extension GitHubBridge {
    static func access() async -> GitHubAccess {
        await GitHub.access()
    }

    static func isAvailable() async -> Bool {
        await GitHub.isAvailable()
    }
}
