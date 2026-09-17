import Foundation

public enum BridgeUserRegistration {
    public enum State: String, Sendable, Hashable {
        case registered
        case notRegistered
        case unknown
    }

    public static var userConfigPath: String { "\(NSHomeDirectory())/.claude.json" }

    public static func state(
        userConfig: Data?,
        serverNamed name: String,
        matching attachment: BridgeAttachment?
    ) -> State {
        guard let userConfig, !userConfig.isEmpty else { return .unknown }
        guard let root = (try? JSONSerialization.jsonObject(with: userConfig)) as? [String: Any] else {
            return .unknown
        }
        guard let servers = root["mcpServers"] as? [String: Any] else { return .notRegistered }
        guard let entry = servers[name] as? [String: Any] else { return .notRegistered }
        guard let attachment else { return .registered }
        return matches(entry: entry, attachment: attachment) ? .registered : .notRegistered
    }

    private static func matches(entry: [String: Any], attachment: BridgeAttachment) -> Bool {
        guard entry["command"] as? String == attachment.shimPath else { return false }
        let environment = entry["env"] as? [String: Any]
        for variable in [BridgeProtocol.socketVariable, BridgeProtocol.tokenVariable] {
            guard environment?[variable] as? String == attachment.environment[variable] else {
                return false
            }
        }
        return true
    }
}
