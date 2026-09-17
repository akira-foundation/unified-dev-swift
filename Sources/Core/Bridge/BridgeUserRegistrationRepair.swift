import Foundation

public enum BridgeUserRegistrationRepair {
    public enum Reason: String, Sendable, Hashable {
        case unreadable
        case malformed
        case absent
        case notOurs
        case alreadyCorrect
        case shimStillThere
    }

    public enum Repair: Sendable, Equatable {
        case leaveAlone(Reason)
        case rewrite(Data, from: String, to: String)
    }

    public enum Outcome: Sendable, Equatable {
        case unchanged(Reason)
        case repaired(from: String, to: String)
        case couldNotWrite(String)
    }

    public static func decide(
        userConfig: Data?,
        serverNamed name: String,
        matching attachment: BridgeAttachment,
        shimExists: (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) }
    ) -> Repair {
        guard let userConfig, !userConfig.isEmpty else { return .leaveAlone(.unreadable) }
        guard var root = (try? JSONSerialization.jsonObject(with: userConfig)) as? [String: Any] else {
            return .leaveAlone(.malformed)
        }
        guard var servers = root["mcpServers"] as? [String: Any] else { return .leaveAlone(.absent) }
        guard var entry = servers[name] as? [String: Any] else { return .leaveAlone(.absent) }
        guard let command = entry["command"] as? String,
              (command as NSString).lastPathComponent == shimName else {
            return .leaveAlone(.notOurs)
        }
        guard isOurs(entry: entry, attachment: attachment) else { return .leaveAlone(.notOurs) }
        guard command != attachment.shimPath else { return .leaveAlone(.alreadyCorrect) }
        guard !shimExists(command) else { return .leaveAlone(.shimStillThere) }

        entry["command"] = attachment.shimPath
        servers[name] = entry
        root["mcpServers"] = servers
        guard let rewritten = try? JSONSerialization.data(
            withJSONObject: root,
            options: [.prettyPrinted, .withoutEscapingSlashes]
        ) else {
            return .leaveAlone(.malformed)
        }
        return .rewrite(rewritten, from: command, to: attachment.shimPath)
    }

    @discardableResult
    public static func repairIfStale(
        path: String = BridgeUserRegistration.userConfigPath,
        serverNamed name: String,
        matching attachment: BridgeAttachment,
        shimExists: (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) }
    ) -> Outcome {
        let contents = FileManager.default.contents(atPath: path)
        let repair = decide(
            userConfig: contents,
            serverNamed: name,
            matching: attachment,
            shimExists: shimExists
        )
        switch repair {
        case .leaveAlone(let reason):
            return .unchanged(reason)
        case .rewrite(let data, let from, let to):
            do {
                try write(data, to: path)
                return .repaired(from: from, to: to)
            } catch {
                return .couldNotWrite(error.readableMessage)
            }
        }
    }

    static let shimName = "bridge"

    private static func isOurs(entry: [String: Any], attachment: BridgeAttachment) -> Bool {
        let environment = entry["env"] as? [String: Any]
        for variable in [BridgeProtocol.socketVariable, BridgeProtocol.tokenVariable] {
            guard environment?[variable] as? String == attachment.environment[variable] else {
                return false
            }
        }
        return true
    }

    private static func write(_ data: Data, to path: String) throws {
        let existing = try? FileManager.default.attributesOfItem(atPath: path)
        try data.write(to: URL(fileURLWithPath: path), options: .atomic)
        if let mode = existing?[.posixPermissions] {
            try? FileManager.default.setAttributes([.posixPermissions: mode], ofItemAtPath: path)
        }
    }
}
