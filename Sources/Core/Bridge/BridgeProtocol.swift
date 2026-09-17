import Foundation

public enum BridgeProtocol {
    public static let version = 1

    public static let socketVariable = "UD_BRIDGE_SOCKET"

    public static let tokenVariable = "UD_BRIDGE_TOKEN"

    public static let roleVariable = "UD_BRIDGE_ROLE"

    public static func problem(with hello: BridgeHello) -> String? {
        guard hello.version != version else { return nil }
        return """
            This copy of Unified Dev speaks bridge protocol \(version) and bridge \
            \(hello.shimDescription) speaks \(hello.version). Quit and reopen Unified Dev.
            """
    }

    public static func unrecognisedToken(claiming role: String) -> String {
        guard role == BridgeRole.owner.rawValue else {
            return "Unified Dev does not recognise this token. It was minted by a previous launch; "
                + "quit and reopen Unified Dev."
        }
        return """
            Unified Dev does not recognise this token. It came from a standalone registration, and that \
            kind of token is meant to outlive a quit, so restarting Unified Dev will not bring it back \
            and no retry with this token will connect. Either the token was regenerated in Unified Dev's \
            Settings, which revokes the one it replaced, or this entry belongs to a different copy \
            of Unified Dev: each copy registers under its own name and keeps its own token beside its \
            own database, so an entry written against a copy that has since been removed, replaced \
            or pointed at other data outlives the token that made it work. Both are put right the \
            same way: open Unified Dev's Settings and run the registration command it offers there again.
            """
    }
}

public struct BridgeHello: Codable, Sendable, Hashable {
    public var version: Int
    public var token: String
    public var role: String
    public var shim: String?

    public init(version: Int = BridgeProtocol.version, token: String, role: String, shim: String? = nil) {
        self.version = version
        self.token = token
        self.role = role
        self.shim = shim
    }

    var shimDescription: String {
        guard let shim, !shim.isEmpty else { return "at an unnamed build" }
        return "(\(shim))"
    }
}

public struct BridgeWelcome: Codable, Sendable, Hashable {
    public var version: Int
    public var accepted: Bool
    public var problem: String?

    public init(version: Int = BridgeProtocol.version, accepted: Bool, problem: String? = nil) {
        self.version = version
        self.accepted = accepted
        self.problem = problem
    }

    public static func accepting() -> BridgeWelcome {
        BridgeWelcome(accepted: true)
    }

    public static func refusing(_ problem: String) -> BridgeWelcome {
        BridgeWelcome(accepted: false, problem: problem)
    }
}
