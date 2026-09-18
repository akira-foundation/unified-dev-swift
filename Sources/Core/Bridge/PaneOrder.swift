import Foundation

public enum PaneOrderReading: Sendable, Equatable {
    case order(PaneOrder)
    case refused(String)
}

public enum PaneOutcome: Sendable, Equatable {
    case opened(String)
    case refused(String)
}

public enum PanePlacement: Sendable, Equatable {
    case front
    case revealed
    case behind
    case refused(String)
}

public struct PaneOrder: Sendable, Equatable {
    public var kind: PaneKind

    public var url: String?

    public var focus: Bool

    public var title: String?

    public init(kind: PaneKind, url: String? = nil, focus: Bool = true, title: String? = nil) {
        self.kind = kind
        self.url = url
        self.focus = kind == .browser ? false : focus
        self.title = title
    }

    public static func name(from raw: String?) -> String? {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }

    public static var kindList: String {
        PaneKind.allCases.map { "'\($0.rawValue)'" }.joined(separator: ", ")
    }

    public static func parse(
        kind rawKind: String?,
        url rawURL: String?,
        focus rawFocus: JSONValue?,
        title rawTitle: String? = nil,
        tool: String
    ) -> PaneOrderReading {
        guard let rawKind, !rawKind.trimmingCharacters(in: .whitespaces).isEmpty else {
            return .refused(
                "\(tool) needs to know what to open. Pass 'kind' as one of \(kindList)."
            )
        }
        guard let kind = PaneKind(rawValue: rawKind.trimmingCharacters(in: .whitespaces)) else {
            return .refused(
                "Unified Dev has no pane called '\(rawKind)'. It opens \(kindList)."
            )
        }

        let url = rawURL?.trimmingCharacters(in: .whitespaces)
        if let url, !url.isEmpty, kind != .browser {
            return .refused(
                "Only a browser pane takes a 'url'. Drop it, or pass kind 'browser'."
            )
        }

        if let url, !url.isEmpty, let scheme = URL(string: url)?.scheme?.lowercased(),
           scheme != "http", scheme != "https" {
            return .refused(
                "A browser pane opens http and https addresses. '\(scheme)' is not one Unified Dev will "
                    + "open on your behalf."
            )
        }

        let focus: Bool
        switch rawFocus {
        case .none, .null: focus = true
        case .bool(let value): focus = value
        default:
            return .refused("'focus' is true or false. Leave it out to bring the pane to the front.")
        }

        return .order(
            PaneOrder(
                kind: kind,
                url: url?.isEmpty == true ? nil : url,
                focus: focus,
                title: name(from: rawTitle)
            )
        )
    }

    public static let nothingToSitBehind =
        "There is nothing open in that workspace for a browser to sit behind, and a browser alone "
            + "in the centre column would fetch its page at once, from the person's own browser, "
            + "without asking them. Open a chat or a terminal first, or ask the person to open the "
            + "browser."

    public static let browserSplitsBlank =
        "pane_split opens a browser pane blank and takes no 'url' for one. A pane beside this chat "
            + "is drawn at once, so it would fetch the page from the person's own browser without "
            + "asking them. Leave out 'url' and point the pane with browser_go, which asks them, or "
            + "use pane_open, which leaves the browser behind the tab in front until they click it."

    public func placement(hasTabInFront: Bool) -> PanePlacement {
        guard kind == .browser else { return focus ? .front : .revealed }
        return hasTabInFront ? .behind : .refused(Self.nothingToSitBehind)
    }

    public var confirmation: String {
        let named = title.map { "\(kind.title) called '\($0)'" } ?? kind.title
        let what = url.map { "\(named) on \($0)" } ?? named
        if kind == .browser {
            return "Opened \(what) behind the tab in front, and it has not fetched anything yet. "
                + "A browser never comes to the front through pane_open, because drawing it loads "
                + "the page from the person's own browser. It loads when they click the tab: ask "
                + "them to, and until then the browser tools that need a page refuse it."
        }
        return focus
            ? "Opened \(what) and brought it to the front."
            : "Opened \(what) in the background. It is in the tab strip but the reader is still on what they were looking at."
    }
}

public struct PaneRefusal: Error, Sendable, Equatable {
    public let sentence: String

    public init(_ sentence: String) {
        self.sentence = sentence
    }
}
