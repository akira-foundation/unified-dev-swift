import CryptoKit
import Foundation

public struct BrowserFaviconLink: Equatable, Sendable {
    public var rel: String
    public var sizes: String
    public var type: String
    public var href: String

    public init(rel: String, sizes: String = "", type: String = "", href: String) {
        self.rel = rel
        self.sizes = sizes
        self.type = type
        self.href = href
    }
}

public enum BrowserFavicon {
    public static let pixels = 32

    public static let linkLimit = 16

    public static let textLimit = 2_048

    public static let loadTimeout = 5_000

    public static let attempts = [250, 1_500]

    public static let byteLimit = 24 * 1_024

    public static let dataPrefix = "data:image/png;base64,"

    public static let dataLimit = dataPrefix.count + ((byteLimit + 2) / 3) * 4

    public static let cacheLimit = 128

    private static let signature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]

    private static let fields = 4

    public static func origin(of address: String) -> String? {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host()?.lowercased(),
              !host.isEmpty
        else { return nil }

        let port = url.port ?? (scheme == "https" ? 443 : 80)
        return "\(scheme)://\(host):\(port)"
    }

    public static func fileName(for origin: String) -> String {
        let digest = SHA256.hash(data: Data(origin.utf8))
        return digest.map { String(format: "%02x", $0) }.joined() + ".png"
    }

    public static func links(from values: [String]) -> [BrowserFaviconLink] {
        guard !values.isEmpty, values.count % fields == 0 else { return [] }
        return stride(from: 0, to: values.count, by: fields).map { start in
            BrowserFaviconLink(
                rel: values[start],
                sizes: values[start + 1],
                type: values[start + 2],
                href: values[start + 3]
            )
        }
    }

    public static func choose(from links: [BrowserFaviconLink]) -> Choice? {
        let ranked = links.prefix(linkLimit).enumerated().compactMap { index, link in
            Ranked(index: index, link: link)
        }
        guard let best = ranked.min(by: Ranked.precedes) else { return nil }
        return Choice(index: best.index, url: best.url)
    }

    public struct Choice: Equatable, Sendable {
        public var index: Int
        public var url: URL

        public init(index: Int, url: URL) {
            self.index = index
            self.url = url
        }
    }

    private struct Ranked {
        var index: Int
        var url: URL
        var kind: Kind
        var size: Int?

        enum Kind: Int {
            case icon
            case appleTouch
        }

        init?(index: Int, link: BrowserFaviconLink) {
            let tokens = Set(
                link.rel.lowercased().components(separatedBy: .whitespacesAndNewlines)
                    .filter { !$0.isEmpty }
            )
            if tokens.contains("icon") {
                kind = .icon
            } else if tokens.contains("apple-touch-icon")
                || tokens.contains("apple-touch-icon-precomposed") {
                kind = .appleTouch
            } else {
                return nil
            }

            guard let url = URL(string: link.href.trimmingCharacters(in: .whitespacesAndNewlines)),
                  let scheme = url.scheme?.lowercased(),
                  scheme == "http" || scheme == "https",
                  url.host()?.isEmpty == false
            else { return nil }

            self.index = index
            self.url = url
            size = BrowserFavicon.square(in: link.sizes)
        }

        var tier: Int {
            guard let size else { return 1 }
            return size >= BrowserFavicon.pixels ? 0 : 2
        }

        static func precedes(_ one: Ranked, _ other: Ranked) -> Bool {
            if one.tier != other.tier { return one.tier < other.tier }
            if let mine = one.size, let theirs = other.size, mine != theirs {
                return one.tier == 0 ? mine < theirs : mine > theirs
            }
            if one.kind != other.kind { return one.kind.rawValue < other.kind.rawValue }
            return one.index < other.index
        }
    }

    private static func square(in sizes: String) -> Int? {
        let tokens = sizes.lowercased().components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        guard !tokens.isEmpty, !tokens.contains("any") else { return nil }

        let squares = tokens.compactMap { token -> Int? in
            let parts = token.components(separatedBy: "x")
            guard parts.count == 2,
                  let width = Int(parts[0]), let height = Int(parts[1]),
                  width > 0, height > 0
            else { return nil }
            return min(width, height)
        }
        return squares.max()
    }

    public static func read(_ dataURL: String) -> Data? {
        guard dataURL.count <= dataLimit, dataURL.hasPrefix(dataPrefix) else { return nil }

        let encoded = String(dataURL.dropFirst(dataPrefix.count))
        guard !encoded.isEmpty, let data = Data(base64Encoded: encoded) else { return nil }
        guard data.count <= byteLimit, data.starts(with: signature) else { return nil }
        return data
    }
}
