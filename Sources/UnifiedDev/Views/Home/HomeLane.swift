import Core

enum HomeLane {
    case working
    case waiting
    case resting
}

extension WorkspaceStatus {
    var homeLane: HomeLane {
        switch self {
        case .settingUp, .running, .checksRunning: .working
        case .awaitingPermission: .waiting
        case .setupFailed, .unread, .conflicted, .checksFailing, .checksPassed, .merged, .closed:
            .waiting
        case .draft, .pullRequestOpen, .changed, .clean: .resting
        }
    }
}
