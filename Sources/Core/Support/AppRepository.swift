import Foundation

public enum AppRepository {
    public static let owner = "akira-foundation"
    public static let name = "unified-dev-swift"
    public static let slug = "\(owner)/\(name)"

    public static let page = URL(string: "https://github.com/\(owner)/\(name)")!
    public static let issuesURL = URL(string: "https://github.com/\(owner)/\(name)/issues")!
    public static let readmeURL = URL(string: "https://github.com/\(owner)/\(name)/blob/main/README.md")!

    public static let urlLimit = 6_000

    public static let cutNotice =
        "\n\nThe rest of this report was cut off here because it did not fit in a link."

    public static func newIssueURL(
        title: String,
        body: String,
        labels: [String] = [],
        cut: (String) -> String = { $0 + cutNotice }
    ) -> URL {
        let full = link(title: title, body: body, labels: labels)
        guard full.absoluteString.count > urlLimit else { return full }

        if let kept = longestFit(of: body, { link(title: title, body: cut($0), labels: labels) }) {
            return link(title: title, body: cut(kept), labels: labels)
        }

        let shorter = longestFit(of: title, { link(title: $0, body: "", labels: labels) }) ?? ""
        return link(title: shorter, body: "", labels: labels)
    }

    private static func longestFit(of text: String, _ build: (String) -> URL) -> String? {
        guard build("").absoluteString.count <= urlLimit else { return nil }

        var fits = 0
        var tooMany = text.count
        while fits < tooMany {
            let candidate = (fits + tooMany + 1) / 2
            if build(String(text.prefix(candidate))).absoluteString.count <= urlLimit {
                fits = candidate
            } else {
                tooMany = candidate - 1
            }
        }
        return String(text.prefix(fits))
    }

    private static func link(title: String, body: String, labels: [String]) -> URL {
        var components = URLComponents(string: "https://github.com/\(owner)/\(name)/issues/new")!
        var query = "title=\(escaped(title))&body=\(escaped(body))"
        if !labels.isEmpty {
            query += "&labels=\(escaped(labels.joined(separator: ",")))"
        }
        components.percentEncodedQuery = query
        return components.url!
    }

    private static func escaped(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: unreserved) ?? ""
    }

    private static let unreserved = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
    )
}
