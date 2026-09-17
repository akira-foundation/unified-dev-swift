import Foundation

public enum WorkspaceSetupPolicy: Sendable {
    case deferred
    case run
    case skip

    public func initialState(script: String?, hasSubmodules: Bool = false) -> SetupState {
        guard self != .skip else { return .skipped }
        let hasScript = script.map { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? false
        return hasScript || hasSubmodules ? .pending : .skipped
    }
}
