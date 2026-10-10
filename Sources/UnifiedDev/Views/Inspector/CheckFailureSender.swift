import SwiftUI
import Core

@MainActor
@Observable
final class CheckFailureSender {
    private(set) var sending: String?

    func isSending(_ run: CheckRun) -> Bool { sending == run.id }

    static func canSend(_ run: CheckRun) -> Bool { CheckState(run) == .failed }

    func send(_ run: CheckRun, in model: WorkspaceModel) async -> String? {
        guard sending == nil else { return nil }
        sending = run.id
        defer { sending = nil }

        return await model.writeCheckFailureRequest(for: [run])
    }
}
