import Foundation

public enum RepoIconDetector {
    public static let smallestUsefulPixels = 32

    public static let widestUsefulAspect = 2.0

    public static func detect(in repo: String) -> RepoIconCandidate? {
        candidates(in: repo).first
    }

    public static func layers(ofIconBundle path: String) -> [RepoIconLayer] {
        RepoIconFile.layers(ofIconBundle: path)
    }

    public static func candidates(in repo: String) -> [RepoIconCandidate] {
        let root = (repo as NSString).expandingTildeInPath
        var found = webCandidates(in: root) + manifestCandidates(in: root) + appCandidates(in: root)

        found.sort { $0.isBetter(than: $1) }
        var seen = Set<String>()
        return found.filter { seen.insert($0.path).inserted }
    }

    static let webRoots = ["", "public", "static", "www", "assets", "resources", "web", "site", "docs"]

    static let iconFolders = ["", "brand", "icons", "icon", "img", "images", "favicon", "favicons"]

    private static func webCandidates(in root: String) -> [RepoIconCandidate] {
        var candidates: [RepoIconCandidate] = []
        for directory in searchDirectories(in: root) {
            for name in (try? FileManager.default.contentsOfDirectory(atPath: directory)) ?? [] {
                guard let origin = origin(ofFileNamed: name) else { continue }
                let path = (directory as NSString).appendingPathComponent(name)
                if let candidate = candidate(at: path, origin: origin) {
                    candidates.append(candidate)
                }
            }
        }
        return candidates
    }

    static func searchDirectories(in root: String) -> [String] {
        var directories: [String] = []
        var seen = Set<String>()
        for web in webRoots {
            for folder in iconFolders {
                let relative = [web, folder].filter { !$0.isEmpty }
                guard let path = resolve(relative, under: root), seen.insert(path).inserted else { continue }
                directories.append(path)
            }
        }
        return directories
    }

    private static func resolve(_ components: [String], under root: String) -> String? {
        var path = root
        for component in components {
            let entries = (try? FileManager.default.contentsOfDirectory(atPath: path)) ?? []
            guard let match = entries.first(where: { $0 == component })
                ?? entries.sorted().first(where: { $0.lowercased() == component })
            else { return nil }
            path = (path as NSString).appendingPathComponent(match)
        }
        return isDirectory(path) ? path : nil
    }

    static func origin(ofFileNamed name: String) -> RepoIconOrigin? {
        let lower = name.lowercased()
        guard RepoIconFormat.fileFormats
            .flatMap(\.fileExtensions)
            .contains(where: { lower.hasSuffix(".\($0)") })
        else { return nil }
        return origin(ofStem: (lower as NSString).deletingPathExtension)
    }

    static func origin(ofStem stem: String) -> RepoIconOrigin? {
        if stem == "favicon" || stem.hasPrefix("favicon-") || stem.hasPrefix("favicon_")
            || stem.hasPrefix("apple-touch-icon") {
            return .favicon
        }

        let brandStems = ["icon", "logo", "mark", "logomark", "appicon", "app-icon", "brand", "avatar"]
        for brand in brandStems
        where stem == brand || stem.hasPrefix("\(brand)-") || stem.hasPrefix("\(brand)_") {
            return .brand
        }
        return nil
    }

    static func decoration(ofFileNamed name: String) -> Int {
        let stem = ((name as NSString).lastPathComponent as NSString)
            .deletingPathExtension
            .lowercased()
        guard origin(ofStem: stem) != nil else { return 0 }

        var segments = stem.split(whereSeparator: { $0 == "-" || $0 == "_" }).map(String.init)
        var added = 0
        while segments.count > 1 {
            let last = segments.removeLast()
            guard origin(ofStem: segments.joined(separator: "-")) != nil else { break }
            if !isMeasurement(last) { added += 1 }
        }
        return added
    }

    private static func isMeasurement(_ segment: String) -> Bool {
        guard segment.contains(where: \.isNumber) else { return false }
        return segment.allSatisfy { $0.isNumber || $0 == "x" || $0 == "@" }
    }

    private static func manifestCandidates(in root: String) -> [RepoIconCandidate] {
        var candidates: [RepoIconCandidate] = []
        for directory in searchDirectories(in: root) {
            for name in ["site.webmanifest", "manifest.webmanifest", "manifest.json"] {
                let path = (directory as NSString).appendingPathComponent(name)
                guard let data = boundedContents(ofFile: path, limit: 256 * 1024),
                      let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let icons = object["icons"] as? [[String: Any]]
                else { continue }

                for icon in icons {
                    guard let source = icon["src"] as? String, !source.isEmpty else { continue }
                    let relative = source.hasPrefix("/") ? String(source.dropFirst()) : source
                    guard !relative.isEmpty, !relative.contains("://") else { continue }
                    let resolved = (directory as NSString).appendingPathComponent(relative)
                    if let candidate = candidate(at: resolved, origin: .manifest) {
                        candidates.append(candidate)
                    }
                }
            }
        }
        return candidates
    }

    static let skippedDirectories: Set<String> = [
        ".git", ".svn", ".hg", "node_modules", "vendor", "Pods", "Carthage", "build", ".build",
        "DerivedData", "dist", "out", "target", ".venv", "venv", "__pycache__", ".next", ".nuxt",
        ".cache", "coverage", "tmp", "bower_components", ".gradle", ".idea", ".swiftpm",
    ]

    static let maximumDepth = 5

    static let maximumEntries = 20_000

    private static func appCandidates(in root: String) -> [RepoIconCandidate] {
        var candidates: [RepoIconCandidate] = []
        var visited = 0
        var queue: [(path: String, depth: Int)] = [(root, 0)]

        while !queue.isEmpty, visited < maximumEntries {
            let (directory, depth) = queue.removeFirst()
            let names = ((try? FileManager.default.contentsOfDirectory(atPath: directory)) ?? []).sorted()
            for name in names {
                visited += 1
                if visited >= maximumEntries { break }
                let path = (directory as NSString).appendingPathComponent(name)

                if name.hasSuffix(".icns") {
                    if let candidate = candidate(at: path, origin: .appIcon) { candidates.append(candidate) }
                    continue
                }
                guard isDirectory(path) else { continue }

                if name.hasSuffix(".appiconset") {
                    if let candidate = largestImage(inAppIconSet: path) { candidates.append(candidate) }
                    continue
                }
                if name.hasSuffix(".icon") {
                    if let candidate = candidate(at: path, origin: .appIcon) { candidates.append(candidate) }
                    continue
                }
                guard depth + 1 <= maximumDepth,
                      !skippedDirectories.contains(name),
                      !name.hasPrefix("."),
                      !name.hasSuffix(".app")
                else { continue }
                queue.append((path, depth + 1))
            }
        }
        return candidates
    }

    private static func largestImage(inAppIconSet path: String) -> RepoIconCandidate? {
        let names = ((try? FileManager.default.contentsOfDirectory(atPath: path)) ?? []).sorted()
        return names
            .compactMap { candidate(at: (path as NSString).appendingPathComponent($0), origin: .appIcon) }
            .min { $0.isBetter(than: $1) }
    }

    static func candidate(at path: String, origin: RepoIconOrigin) -> RepoIconCandidate? {
        guard let measurement = RepoIconFile.measure(path) else { return nil }
        if measurement.format.isRaster, measurement.pixels < smallestUsefulPixels { return nil }
        if let aspect = measurement.aspect, aspect > widestUsefulAspect { return nil }
        return RepoIconCandidate(
            path: path,
            format: measurement.format,
            origin: origin,
            pixels: measurement.pixels,
            aspect: measurement.aspect,
            decoration: decoration(ofFileNamed: path)
        )
    }

    static func hasPlainerName(than name: String, among names: [String]) -> Bool {
        let name = (name as NSString).lastPathComponent
        guard let kind = origin(ofFileNamed: name) else { return false }
        let added = decoration(ofFileNamed: name)
        guard added > 0 else { return false }
        let fileExtension = (name as NSString).pathExtension.lowercased()

        return names.contains { other in
            other.lowercased() != name.lowercased()
                && (other as NSString).pathExtension.lowercased() == fileExtension
                && origin(ofFileNamed: other) == kind
                && decoration(ofFileNamed: other) < added
        }
    }

    static func isDirectory(_ path: String) -> Bool {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else { return false }
        return isDirectory.boolValue
    }

    static func boundedContents(ofFile path: String, limit: Int) -> Data? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
              let size = attributes[.size] as? NSNumber, size.intValue <= limit
        else { return nil }
        return FileManager.default.contents(atPath: path)
    }
}

public enum RepoIconOrigin: String, Sendable, Hashable, Codable, CaseIterable {
    case brand
    case manifest
    case favicon
    case appIcon

    var rank: Int {
        switch self {
        case .brand: 1
        case .manifest: 2
        case .favicon: 3
        case .appIcon: 4
        }
    }
}

public enum RepoIconFormat: String, Sendable, Hashable, Codable, CaseIterable {
    case svg
    case icns
    case layered
    case png
    case ico
    case jpeg

    static var fileFormats: [RepoIconFormat] { [.svg, .png, .ico, .icns, .jpeg] }

    var fileExtensions: [String] {
        switch self {
        case .svg: ["svg"]
        case .icns: ["icns"]
        case .layered: ["icon"]
        case .png: ["png"]
        case .ico: ["ico"]
        case .jpeg: ["jpg", "jpeg"]
        }
    }

    public var isRaster: Bool {
        switch self {
        case .svg, .layered: false
        case .icns, .png, .ico, .jpeg: true
        }
    }

    var tier: Int {
        switch self {
        case .svg: 5
        case .icns: 4
        case .layered: 3
        case .png, .ico: 2
        case .jpeg: 1
        }
    }
}

public struct RepoIconCandidate: Sendable, Hashable, Codable {
    public var path: String
    public var format: RepoIconFormat
    public var origin: RepoIconOrigin
    public var pixels: Int
    public var aspect: Double?
    public var decoration: Int

    public init(
        path: String,
        format: RepoIconFormat,
        origin: RepoIconOrigin,
        pixels: Int,
        aspect: Double? = nil,
        decoration: Int = 0
    ) {
        self.path = path
        self.format = format
        self.origin = origin
        self.pixels = pixels
        self.aspect = aspect
        self.decoration = decoration
    }

    var shape: Int {
        guard let aspect else { return 0 }
        if aspect <= 1.1 { return 0 }
        if aspect <= 1.4 { return 1 }
        return 2
    }

    public func isBetter(than other: RepoIconCandidate) -> Bool {
        if origin.rank != other.origin.rank { return origin.rank > other.origin.rank }
        if format.tier != other.format.tier { return format.tier > other.format.tier }
        if shape != other.shape { return shape < other.shape }
        if decoration != other.decoration { return decoration < other.decoration }
        if pixels != other.pixels { return pixels > other.pixels }
        let depth = path.components(separatedBy: "/").count
        let otherDepth = other.path.components(separatedBy: "/").count
        if depth != otherDepth { return depth < otherDepth }
        return path < other.path
    }
}
