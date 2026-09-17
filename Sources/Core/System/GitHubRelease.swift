import Foundation

public struct GitHubRelease: Equatable, Sendable {
    public struct Asset: Equatable, Sendable {
        public let name: String
        public let downloadURL: URL
        public let size: Int
        public let sha256: String?

        public init(name: String, downloadURL: URL, size: Int, sha256: String?) {
            self.name = name
            self.downloadURL = downloadURL
            self.size = size
            self.sha256 = sha256
        }
    }

    public let tag: String
    public let version: ReleaseVersion
    public let notes: String
    public let pageURL: URL
    public let isPrerelease: Bool
    public let isDraft: Bool
    public let assets: [Asset]

    public init(
        tag: String, version: ReleaseVersion, notes: String, pageURL: URL,
        isPrerelease: Bool, isDraft: Bool, assets: [Asset]
    ) {
        self.tag = tag
        self.version = version
        self.notes = notes
        self.pageURL = pageURL
        self.isPrerelease = isPrerelease
        self.isDraft = isDraft
        self.assets = assets
    }

    public enum DecodingTrouble: Error, Equatable, Sendable {
        case unreadable
        case notAVersion(tag: String)
    }

    public static func decode(_ data: Data) throws -> GitHubRelease {
        guard let payload = try? JSONDecoder().decode(Payload.self, from: data),
              let pageURL = URL(string: payload.htmlURL), isGitHubURL(pageURL) else {
            throw DecodingTrouble.unreadable
        }
        guard let version = ReleaseVersion(payload.tagName) else {
            throw DecodingTrouble.notAVersion(tag: payload.tagName)
        }

        let assets = payload.assets.compactMap { asset -> Asset? in
            guard let url = URL(string: asset.browserDownloadURL), isGitHubURL(url) else { return nil }
            return Asset(name: asset.name, downloadURL: url, size: asset.size, sha256: sha256(fromDigest: asset.digest))
        }

        return GitHubRelease(
            tag: payload.tagName,
            version: version,
            notes: payload.body ?? "",
            pageURL: pageURL,
            isPrerelease: payload.prerelease,
            isDraft: payload.draft,
            assets: assets
        )
    }

    public func asset(named name: String) -> Asset? {
        assets.first { $0.name == name }
    }

    public static func isGitHubURL(_ url: URL) -> Bool {
        url.scheme == "https" && url.host() == "github.com"
    }

    static func sha256(fromDigest digest: String?) -> String? {
        guard let digest, digest.hasPrefix("sha256:") else { return nil }
        let hex = digest.dropFirst("sha256:".count).lowercased()
        guard hex.count == 64, hex.allSatisfy(\.isHexDigit) else { return nil }
        return String(hex)
    }

    private struct Payload: Decodable {
        let tagName: String
        let htmlURL: String
        let body: String?
        let prerelease: Bool
        let draft: Bool
        let assets: [AssetPayload]

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlURL = "html_url"
            case body, prerelease, draft, assets
        }
    }

    private struct AssetPayload: Decodable {
        let name: String
        let browserDownloadURL: String
        let size: Int
        let digest: String?

        enum CodingKeys: String, CodingKey {
            case name, size, digest
            case browserDownloadURL = "browser_download_url"
        }
    }
}
