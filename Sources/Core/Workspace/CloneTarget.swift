import Foundation

public enum CloneRefusal: Sendable, Equatable {
    case empty
    case unsafeTransport(String)
    case unsupported(String)
    case noName(String)
    case occupied(String)

    public var sentence: String {
        switch self {
        case .empty:
            "Paste the address of a repository, and Unified Dev will clone it into a new project."

        case .unsafeTransport(let helper):
            "A \(helper) address tells git to run a command of its own, so Unified Dev will not "
                + "clone one. Use an https or an ssh address."

        case .unsupported(let remote):
            "\(remote) is not an address git can clone. Use an https address, an ssh address, or a "
                + "path on this Mac."

        case .noName(let remote):
            "\(remote) does not say what the repository is called, so there is no name to give the "
                + "folder."

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

public extension CloneTarget {
    internal static let safeSchemes: Set<String> = ["https", "http", "ssh", "git", "file"]

    static func name(of remote: String) -> String? {
        guard let path = path(of: remote), !path.isEmpty else { return nil }
        return bare((path as NSString).lastPathComponent)
    }

    internal static func path(of remote: String) -> String? {
        var trimmed = remote.trimmingCharacters(in: .whitespacesAndNewlines)
        while trimmed.hasSuffix("/") { trimmed.removeLast() }
        guard !trimmed.isEmpty else { return nil }

        if let scheme = trimmed.range(of: "://") {
            let afterScheme = String(trimmed[scheme.upperBound...])
            guard let slash = afterScheme.firstIndex(of: "/") else { return nil }
            return String(afterScheme[afterScheme.index(after: slash)...])
        }
        if trimmed.hasPrefix("/") || trimmed.hasPrefix("~") { return trimmed }
        guard let colon = trimmed.firstIndex(of: ":") else { return trimmed }
        return String(trimmed[trimmed.index(after: colon)...])
    }

    private static func bare(_ component: String) -> String? {
        var name = component
        if name.hasSuffix(".git") { name.removeLast(4) }
        guard !name.isEmpty, name != ".", name != ".." else { return nil }
        guard !name.contains("\0") else { return nil }
        return name
    }

    internal static func transportHelper(in remote: String) -> String? {
        guard let marker = remote.range(of: "::") else { return nil }
        let head = String(remote[remote.startIndex..<marker.lowerBound])
        guard !head.contains("/"), !head.isEmpty else { return nil }
        return head
    }

    internal static func isAddress(_ remote: String) -> Bool {
        if remote.hasPrefix("/") || remote.hasPrefix("~") { return true }
        if let scheme = remote.range(of: "://") {
            let named = String(remote[remote.startIndex..<scheme.lowerBound]).lowercased()
            return safeSchemes.contains(named)
        }
        guard let colon = remote.firstIndex(of: ":") else { return false }
        let host = String(remote[remote.startIndex..<colon])
        return !host.isEmpty && !host.contains("/") && remote.index(after: colon) < remote.endIndex
    }
}

public extension CloneVerdict {
    static func of(
        remote typed: String,
        into location: String,
        existing: (String) -> Bool = FolderPath.hasContents
    ) -> CloneVerdict {
        let remote = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !remote.isEmpty else { return .refuse(.empty) }
        guard !remote.hasPrefix("-"), !remote.contains("\0") else {
            return .refuse(.unsupported(remote))
        }
        if let helper = CloneTarget.transportHelper(in: remote) {
            return .refuse(.unsafeTransport(helper))
        }
        guard CloneTarget.isAddress(remote) else { return .refuse(.unsupported(remote)) }
        guard let name = CloneTarget.name(of: remote) else { return .refuse(.noName(remote)) }

        let destination = (location as NSString).appendingPathComponent(name)
        guard !existing(destination) else { return .refuse(.occupied(destination)) }
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
