import Foundation

public enum BrowserAddress {
    public static func url(from text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(" ") else { return nil }

        if trimmed.contains("://") { return URL(string: trimmed) }

        let host = trimmed.split(separator: "/", maxSplits: 1).first.map(String.init) ?? trimmed
        let local = isLocal(host: host)
        guard local || host.contains(".") else { return nil }
        return URL(string: (local ? "http://" : "https://") + trimmed)
    }

    public static func isLocal(host: String) -> Bool {
        host.hasPrefix("localhost") || host.hasPrefix("127.0.0.1")
            || host.hasPrefix("0.0.0.0") || host.hasSuffix(".localhost")
    }

    public static func shows(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            return false
        }
        return self.url(from: url.absoluteString) != nil
    }

    public static func external(from address: String) -> URL? {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains("://"), let url = url(from: trimmed), shows(url),
              url.host()?.isEmpty == false
        else { return nil }
        return url
    }
}
