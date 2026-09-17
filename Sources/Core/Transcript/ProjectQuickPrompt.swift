import Foundation

public struct ProjectQuickPrompt: Identifiable, Sendable, Hashable {
    public var name: String
    public var text: String
    public var symbol: String
    public var opensNewChat: Bool
    public var source: String

    public init(
        name: String, text: String, symbol: String = QuickPrompt.defaultSymbol,
        opensNewChat: Bool = false, source: String = ""
    ) {
        self.name = name
        self.text = text
        self.symbol = symbol
        self.opensNewChat = opensNewChat
        self.source = source
    }

    public var id: String { Self.identity(of: name) }

    public static func identity(of name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    public var preview: String {
        QuickPrompt(name: name, text: text).preview
    }

    public var chatTitle: String { name }

    public func delivery(canOpenNewChat: Bool) -> QuickPromptDelivery {
        opensNewChat && canOpenNewChat ? .composeInNewChat : .compose
    }

    public var personalFields: QuickPrompt.Fields {
        QuickPrompt.Fields(
            name: name, symbol: symbol, text: text, sendsImmediately: false,
            opensNewChat: opensNewChat
        )
    }
}
