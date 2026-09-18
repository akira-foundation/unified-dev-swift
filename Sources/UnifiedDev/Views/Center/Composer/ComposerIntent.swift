import Foundation
import Core

enum ComposerIntent {
    case send
    case create
    case open

    init(_ action: WorkspaceDraftAction) {
        switch action {
        case .create: self = .create
        case .open: self = .open
        }
    }

    var title: String {
        switch self {
        case .send: "Send"
        case .create: WorkspaceDraftAction.create.title
        case .open: WorkspaceDraftAction.open.title
        }
    }

    var help: String {
        switch self {
        case .send: "Send (Return)"
        case .create: "Create the workspace (Return)"
        case .open: "Open the workspace (Return)"
        }
    }
}
