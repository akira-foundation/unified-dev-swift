import Foundation

public struct DocumentPreviewExitPrompt: Sendable, Equatable {
    public var title: String
    public var message: String
    public var confirm: String

    public init(title: String, message: String, confirm: String) {
        self.title = title
        self.message = message
        self.confirm = confirm
    }

    public static func asking(about url: URL) -> Self {
        let scheme = url.scheme?.lowercased() ?? ""
        if scheme == "mailto" {
            let address = url.absoluteString.dropFirst("mailto:".count)
            return Self(
                title: "Write to \(address.isEmpty ? "this address" : String(address))?",
                message: "This page asked to start a message in your mail app. "
                    + "The preview itself reaches no network, but your mail app does.",
                confirm: "Open Mail"
            )
        }
        let host = url.host(percentEncoded: false) ?? "another site"
        return Self(
            title: "Open \(host) in your browser?",
            message: "This page asked to open \(LinkPolicy.shortened(url.absoluteString)). "
                + "The preview itself reaches no network, but your browser does, "
                + "and a page can put anything it has read into a link.",
            confirm: "Open in Browser"
        )
    }
}
