import Foundation

public struct QuickPrompt: Identifiable, Sendable, Hashable {
    public var id: QuickPromptID
    public var name: String
    public var symbol: String
    public var text: String
    public var sendsImmediately: Bool
    public var opensNewChat: Bool
    public var sortOrder: Int
    public var createdAt: Date

    public init(
        id: QuickPromptID = .new(),
        name: String,
        symbol: String = QuickPrompt.defaultSymbol,
        text: String,
        sendsImmediately: Bool = false,
        opensNewChat: Bool = false,
        sortOrder: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.text = text
        self.sendsImmediately = sendsImmediately
        self.opensNewChat = opensNewChat
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }

    public struct Fields: Sendable, Equatable {
        public var name: String
        public var symbol: String
        public var text: String
        public var sendsImmediately: Bool
        public var opensNewChat: Bool

        public init(
            name: String,
            symbol: String = QuickPrompt.defaultSymbol,
            text: String,
            sendsImmediately: Bool = false,
            opensNewChat: Bool = false
        ) {
            self.name = name
            self.symbol = symbol
            self.text = text
            self.sendsImmediately = sendsImmediately
            self.opensNewChat = opensNewChat
        }
    }

    public var fields: Fields {
        get {
            Fields(
                name: name,
                symbol: symbol,
                text: text,
                sendsImmediately: sendsImmediately,
                opensNewChat: opensNewChat
            )
        }
        set {
            name = newValue.name
            symbol = newValue.symbol
            text = newValue.text
            sendsImmediately = newValue.sendsImmediately
            opensNewChat = newValue.opensNewChat
        }
    }

    public static let defaultSymbol = "text.alignleft"

    public static let symbols: [String] = QuickPromptMarkCatalog.all.compactMap {
        guard case .symbol(let name) = $0.mark else { return nil }
        return name
    }

    static let knownSymbols = Set(symbols)

    public static func resolvedSymbol(_ symbol: String) -> String {
        QuickPromptMark(stored: symbol).stored
    }

    public var preview: String {
        let folded = text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard folded.count > Self.previewLength else { return folded }
        return folded.prefix(Self.previewLength).trimmingCharacters(in: .whitespaces) + "\u{2026}"
    }

    static let previewLength = 72

    public var resolvedName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty else { return trimmed }
        return preview
    }

    public var chatTitle: String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    public var hasSeparatePreview: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
