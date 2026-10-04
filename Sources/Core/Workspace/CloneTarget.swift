import Foundation

public enum CloneRefusal: Sendable, Equatable {
    case empty
    case unsafeTransport(String)
    case unsupported(String)
    case noName(String)
    case browserAddress(String)
    case embeddedPassword
    case occupied(String)

    public var sentence: String {
        switch self {
        case .empty:
            "Paste the address of a repository, and Unified Dev will clone it into a new project."

        case .unsafeTransport(let helper):
            "A \(helper) address tells git to run a command of its own, so Unified Dev will not "
                + "clone one. Use an https or an ssh address."

        case .unsupported(let remote):
            "\(remote) is not an address Unified Dev will clone. Use an https address, an ssh "
                + "address, or a path on this Mac. Plain http and git addresses are refused "
                + "because neither proves which server answered."

        case .noName(let remote):
            "\(remote) does not say what the repository is called, so there is no name to give the "
                + "folder."

        case .browserAddress(let marker):
            "That is a page on the site rather than the repository: everything from \(marker) "
                + "onwards is the web interface. Use the address its clone button offers."

        case .embeddedPassword:
            "That address carries a password or a token. git would write it in plain text into the "
                + "project's own .git/config, where every agent working there can read it. Clone "
                + "over ssh, or let a git credential helper hold it."

        case .occupied(let shown):
            "\(shown) already has something in it. Clone somewhere else, or add that folder as a "
                + "project instead."
        }
    }
}

public struct CloneTarget: Sendable, Equatable {
    public var remote: String
    public var name: String
    public var destination: String

    public init(remote: String, name: String, destination: String) {
        self.remote = remote
        self.name = name
        self.destination = destination
    }
}

public enum CloneVerdict: Sendable, Equatable {
    case clone(CloneTarget)
    case refuse(CloneRefusal)

    public var isAllowed: Bool {
        if case .refuse = self { return false }
        return true
    }

    public var target: CloneTarget? {
        guard case .clone(let target) = self else { return nil }
        return target
    }
}

public extension CloneVerdict {
    static func of(
        remote typed: String,
        into location: String,
        home: String,
        isFree: (String) -> Bool = FolderPath.isFree
    ) -> CloneVerdict {
        let remote = CloneAddress.resolved(typed, home: home)
        guard !remote.isEmpty else { return .refuse(.empty) }
        guard !remote.hasPrefix("-"), !remote.contains("\0") else {
            return .refuse(.unsupported(remote))
        }
        if let helper = CloneAddress.transportHelper(in: remote) {
            return .refuse(.unsafeTransport(helper))
        }
        guard CloneAddress.isSupported(remote) else { return .refuse(.unsupported(remote)) }
        guard !CloneAddress.embeddedPassword(in: remote) else { return .refuse(.embeddedPassword) }
        if let marker = CloneAddress.webInterfaceMarker(in: remote) {
            return .refuse(.browserAddress(marker))
        }
        guard let name = CloneAddress.name(of: remote) else { return .refuse(.noName(remote)) }

        let destination = (location as NSString).appendingPathComponent(name)
        guard isFree(destination) else { return .refuse(.occupied(destination)) }
        return .clone(CloneTarget(remote: remote, name: name, destination: destination))
    }
}

public extension ProjectConsequence {
    static func cloning(_ verdict: CloneVerdict, home: String) -> ProjectConsequence {
        switch verdict {
        case .clone(let target):
            ProjectConsequence(
                lead: "\(NewProjectPlan.display(target.destination, home: home)) is where it lands.",
                detail: "git clone, and the folder is added as a project. Nothing already on this "
                    + "Mac is changed.",
                tone: .going
            )

        case .refuse(let refusal):
            ProjectConsequence(
                detail: refusal.sentence,
                tone: refusal == .empty ? .waiting : .refusal
            )
        }
    }
}
