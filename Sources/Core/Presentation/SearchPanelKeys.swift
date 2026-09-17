import Foundation

public enum SearchPanelKey: Equatable, Sendable {
    case up
    case down
    case tab
    case backTab
    case returnKey
    case commandReturn
    case right
    case escape
    case backspaceOnEmpty
}

public enum SearchPanelOutcome: Equatable, Sendable {
    case move(Int)
    case open
    case drill
    case scope(HomeScope)
    case leaveMode
    case clearQuery
    case close
    case handled
    case ignored
}

public struct SearchPanelKeyContext: Equatable, Sendable {
    public var mode: SearchPanelMode
    public var rowCount: Int
    public var highlighted: Int?
    public var isQueryEmpty: Bool
    public var scope: HomeScope
    public var scopes: [HomeScope]
    public var canDrill: Bool
    public var caretAtEnd: Bool

    public init(
        mode: SearchPanelMode = .things,
        rowCount: Int = 0,
        highlighted: Int? = nil,
        isQueryEmpty: Bool = true,
        scope: HomeScope = .all,
        scopes: [HomeScope] = HomeScope.offered(searching: true),
        canDrill: Bool = false,
        caretAtEnd: Bool = true
    ) {
        self.mode = mode
        self.rowCount = rowCount
        self.highlighted = highlighted
        self.isQueryEmpty = isQueryEmpty
        self.scope = scope
        self.scopes = scopes
        self.canDrill = canDrill
        self.caretAtEnd = caretAtEnd
    }
}

public enum SearchPanelKeys {
    public static func outcome(
        for key: SearchPanelKey, in context: SearchPanelKeyContext
    ) -> SearchPanelOutcome {
        switch key {
        case .up, .down:
            guard let index = ListNavigation.destination(
                for: key == .down ? .down : .up,
                from: context.highlighted,
                count: context.rowCount
            ) else {
                return .handled
            }
            return index == context.highlighted ? .handled : .move(index)

        case .tab, .backTab:
            guard context.mode.showsScopes, !context.scopes.isEmpty else { return .ignored }
            let step = key == .tab ? 1 : -1
            let current = context.scopes.firstIndex(of: context.scope) ?? 0
            let next = (current + step + context.scopes.count) % context.scopes.count
            return .scope(context.scopes[next])

        case .returnKey:
            return context.highlighted == nil ? .handled : .open

        case .commandReturn:
            return context.canDrill ? .drill : .handled

        case .right:
            guard context.caretAtEnd else { return .ignored }
            return context.canDrill ? .drill : .ignored

        case .escape:
            return context.isQueryEmpty ? .close : .clearQuery

        case .backspaceOnEmpty:
            return context.mode == .things ? .ignored : .leaveMode
        }
    }

    public static func footer(
        for mode: SearchPanelMode, isSearching: Bool
    ) -> [SearchPanelFooterKey] {
        switch mode {
        case .things:
            var keys = [
                SearchPanelFooterKey(key: "\u{21A9}", label: "Open"),
                SearchPanelFooterKey(key: "\u{2318}\u{21A9}", label: "Actions"),
            ]
            keys.append(
                isSearching
                    ? SearchPanelFooterKey(key: "\u{21E5}", label: "Scope")
                    : SearchPanelFooterKey(key: ">", label: "Commands")
            )
            keys.append(SearchPanelFooterKey(key: "esc", label: "Close"))
            return keys
        case .commands:
            return [
                SearchPanelFooterKey(key: "\u{21A9}", label: "Run"),
                SearchPanelFooterKey(key: "\u{232B}", label: "Leave commands"),
                SearchPanelFooterKey(key: "esc", label: "Close"),
            ]
        case .actions:
            return [
                SearchPanelFooterKey(key: "\u{21A9}", label: "Run"),
                SearchPanelFooterKey(key: "\u{232B}", label: "Back"),
                SearchPanelFooterKey(key: "esc", label: "Close"),
            ]
        }
    }
}

public struct SearchPanelFooterKey: Equatable, Sendable, Identifiable {
    public var key: String
    public var label: String

    public var id: String { label }

    public init(key: String, label: String) {
        self.key = key
        self.label = label
    }
}
