import Foundation

public enum BridgeWorkspaceScope {
    public static let roles: Set<BridgeRole> = [.workspace]

    public static func refusal(tool: String, doing: String) -> String {
        "\(tool) \(doing) the workspace you are in, and this connection is not speaking for one."
    }
}
