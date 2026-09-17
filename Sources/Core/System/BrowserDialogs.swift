import Foundation

public struct BrowserDialogs: Sendable, Equatable {
    public enum Kind: Sendable, Equatable {
        case alert
        case confirm
        case prompt
    }

    public struct Presentation: Sendable, Equatable {
        public var title: String
        public var message: String
        public var defaultText: String
        public var offersSuppression: Bool

        public init(
            title: String,
            message: String,
            defaultText: String = "",
            offersSuppression: Bool = false
        ) {
            self.title = title
            self.message = message
            self.defaultText = defaultText
            self.offersSuppression = offersSuppression
        }
    }

    public enum Decision: Sendable, Equatable {
        case show(Presentation)
        case suppress
    }

    public static let suppressionOffered = 2
    public static let messageLimit = 900
    public static let lineLimit = 12

    private var shown = 0
    private var isSilenced = false

    public init() {}

    public mutating func request(
        _ kind: Kind,
        message: String,
        defaultText: String = "",
        from name: String? = nil
    ) -> Decision {
        guard !isSilenced else { return .suppress }
        shown += 1
        return .show(
            Presentation(
                title: Self.title(from: name),
                message: Self.readable(message),
                defaultText: kind == .prompt ? Self.oneLine(defaultText) : "",
                offersSuppression: shown >= Self.suppressionOffered
            )
        )
    }

    public mutating func silence() {
        isSilenced = true
    }

    public mutating func pageCommitted() {
        shown = 0
        isSilenced = false
    }

    public var isSilent: Bool { isSilenced }

    static func title(from name: String?) -> String {
        guard let name else { return "This page says" }
        return "\(name) says"
    }

    static func readable(_ message: String) -> String {
        var text = String(message.unicodeScalars.filter { scalar in
            scalar == "\n" || scalar == "\t" || !CharacterSet.controlCharacters.contains(scalar)
        })

        var lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        if lines.count > lineLimit {
            lines = Array(lines.prefix(lineLimit))
            text = lines.joined(separator: "\n") + "\n..."
        } else {
            text = lines.joined(separator: "\n")
        }

        if text.count > messageLimit {
            text = String(text.prefix(messageLimit)) + "..."
        }
        return text
    }

    static func oneLine(_ text: String) -> String {
        let flattened = readable(text)
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
        return String(flattened.prefix(messageLimit))
    }
}
