import Foundation
import Observation
import Core

struct WorkspaceNameReveal: Equatable, Identifiable {
    let id = UUID()
    let name: String
    let seed: UInt64
}

@MainActor
@Observable
final class WorkspaceNameReveals {
    static let shared = WorkspaceNameReveals()

    private(set) var reveals: [WorkspaceID: WorkspaceNameReveal] = [:]

    private static let lifetime = ScrambleReveal.interval * (ScrambleReveal.steps + 4)

    private var expiries: [WorkspaceID: Task<Void, Never>] = [:]

    func announce(workspaceID: WorkspaceID, name: String) {
        reveals[workspaceID] = WorkspaceNameReveal(name: name, seed: UInt64.random(in: .min ... .max))

        expiries[workspaceID]?.cancel()
        expiries[workspaceID] = Task { [weak self] in
            try? await Task.sleep(for: Self.lifetime)
            guard !Task.isCancelled else { return }
            self?.reveals[workspaceID] = nil
            self?.expiries[workspaceID] = nil
        }
    }

    func reveal(for workspaceID: WorkspaceID, showing name: String) -> WorkspaceNameReveal? {
        guard let reveal = reveals[workspaceID], reveal.name == name else { return nil }
        return reveal
    }
}
