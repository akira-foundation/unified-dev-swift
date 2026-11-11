import Foundation

public enum GitHubLogin: Sendable, Hashable {
    case thisMac
    case profile(ProfileID, directory: URL)

    public static let directoryVariable = "GH_CONFIG_DIR"
    public static let tokenVariables = ["GH_TOKEN", "GITHUB_TOKEN", "GH_ENTERPRISE_TOKEN", "GITHUB_ENTERPRISE_TOKEN"]

    public var directory: URL? {
        switch self {
        case .thisMac: nil
        case .profile(_, let directory): directory
        }
    }

    public var variables: [String: String] {
        guard let directory else { return [:] }
        var result = Dictionary(uniqueKeysWithValues: Self.tokenVariables.map { ($0, "") })
        result[Self.directoryVariable] = directory.path
        return result
    }

    public func applied(to environment: [String: String]) -> [String: String] {
        guard let directory else { return environment }
        var result = environment
        for name in Self.tokenVariables { result.removeValue(forKey: name) }
        result[Self.directoryVariable] = directory.path
        return result
    }

    public var signInCommand: String {
        guard let directory else { return "gh auth login" }
        return "\(Self.directoryVariable)=\(BridgeRegistration.shellQuoted(directory.path)) gh auth login"
    }

    public func prepare() throws {
        guard let directory else { return }
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700]
        )
    }
}
