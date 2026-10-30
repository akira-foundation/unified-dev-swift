import Foundation

extension PreviewScenario {
    public static let seededUpdateKey = "preview.seededUpdate"

    public struct Update: Sendable, Equatable, Codable {
        public var version: String
        public var current: String
        public var notes: String

        public init(version: String, current: String, notes: String = "") {
            self.version = version
            self.current = current
            self.notes = notes
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            version = try container.decode(String.self, forKey: .version)
            current = try container.decode(String.self, forKey: .current)
            notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        }

        public var currentVersion: ReleaseVersion? { ReleaseVersion(current) }

        public var offeredVersion: ReleaseVersion? { ReleaseVersion(version) }

        public func release() -> GitHubRelease? {
            guard let offered = offeredVersion else { return nil }
            let tag = "v\(offered)"
            guard let page = URL(string: "https://github.com/\(SoftwareUpdate.repository)/releases/tag/\(tag)"),
                  let download = URL(
                      string: "https://github.com/\(SoftwareUpdate.repository)/releases/download/"
                          + "\(tag)/\(SoftwareUpdate.assetName(for: offered))"
                  ) else {
                return nil
            }
            return GitHubRelease(
                tag: tag,
                version: offered,
                notes: notes,
                pageURL: page,
                isPrerelease: false,
                isDraft: false,
                assets: [
                    GitHubRelease.Asset(
                        name: SoftwareUpdate.assetName(for: offered),
                        downloadURL: download,
                        size: 42_000_000,
                        sha256: nil
                    ),
                ]
            )
        }
    }

    var updateProblems: [String] {
        guard let update else { return [] }
        var problems: [String] = []
        guard let offered = update.offeredVersion else {
            return ["the seeded update offers \"\(update.version)\", which is not a version"]
        }
        guard let current = update.currentVersion else {
            return ["the seeded update says this copy is \"\(update.current)\", which is not a version"]
        }
        if !(current < offered) {
            problems.append(
                "the seeded update offers \(offered) to a copy already on \(current), which is nothing to offer"
            )
        }
        if offered.isPrerelease {
            problems.append("the seeded update offers \(offered), and a prerelease is never offered")
        }
        return problems
    }
}
