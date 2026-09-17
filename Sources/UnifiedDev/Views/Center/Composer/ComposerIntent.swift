import Foundation

enum ComposerIntent {
    case send
    case create

    var title: String {
        switch self {
        case .send: "Send"
        case .create: "Create"
        }
    }

    var help: String {
        switch self {
        case .send: "Send (Return)"
        case .create: "Create the workspace (Return)"
        }
    }
}
