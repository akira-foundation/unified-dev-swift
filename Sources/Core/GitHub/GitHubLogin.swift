import Foundation

public enum GitHubLogin: Sendable, Hashable {
    case thisMac
    case profile(ProfileID, directory: URL)
    case unresolved(directory: URL)

    public static let directoryVariable = "GH_CONFIG_DIR"
    public static let tokenVariables = ["GH_TOKEN", "GITHUB_TOKEN", "GH_ENTERPRISE_TOKEN", "GITHUB_ENTERPRISE_TOKEN"]
    public static let signedOutToken = "unified-dev-profile-signed-out"

    public var directory: URL? {
        switch self {
        case .thisMac: nil
        case .profile(_, let directory): directory
        case .unresolved(let directory): directory
        }
    }

    public var holdsToken: Bool {
        switch self {
        case .thisMac: true
        case .unresolved: false
        case .profile(_, let directory): GitHubHostsFile.holdsToken(in: directory)
        }
    }

    public var variables: [String: String] {
        guard let directory else { return [:] }
        var result = Dictionary(uniqueKeysWithValues: Self.tokenVariables.map { ($0, "") })
        result[Self.directoryVariable] = directory.path
        if !holdsToken { result["GH_TOKEN"] = Self.signedOutToken }
        return result
    }

    public func applied(to environment: [String: String]) -> [String: String] {
        guard directory != nil else { return environment }
        return signInEnvironment(from: environment).merging(variables.filter { !$0.value.isEmpty }) { _, login in login }
    }

    public func signInEnvironment(from environment: [String: String]) -> [String: String] {
        guard let directory else { return environment }
        var result = environment
        for name in Self.tokenVariables { result.removeValue(forKey: name) }
        result[Self.directoryVariable] = directory.path
        return result
    }

    public var signInArguments: [String] {
        directory == nil ? ["auth", "login"] : ["auth", "login", "--insecure-storage"]
    }

    public var acceptsSignIn: Bool {
        switch self {
        case .thisMac, .profile: true
        case .unresolved: false
        }
    }

    public var signInCommand: String {
        let command = (["gh"] + signInArguments).joined(separator: " ")
        guard let directory else { return command }
        return "\(Self.directoryVariable)=\(BridgeRegistration.shellQuoted(directory.path)) \(command)"
    }

    public func prepare() throws {
        guard case .profile(_, let directory) = self else { return }
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700]
        )
    }
}
