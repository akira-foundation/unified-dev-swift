import Foundation
import Observation
import Core

@MainActor
@Observable
final class BranchKeptNotices {
    static let shared = BranchKeptNotices()

    private(set) var notices: [WorkspaceID: BranchKeptNotice] = [:]

    func post(_ notice: BranchKeptNotice, for workspaceID: WorkspaceID) {
        notices[workspaceID] = notice
    }

    func dismiss(_ workspaceID: WorkspaceID) {
        notices[workspaceID] = nil
    }
}
