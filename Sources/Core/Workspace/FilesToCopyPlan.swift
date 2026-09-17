import Foundation

public struct FilesToCopyPlan: Sendable, Hashable {
    public struct Match: Sendable, Hashable, Identifiable {
        public var path: String
        public var isDirectory: Bool

        public var id: String { path }

        public init(path: String, isDirectory: Bool) {
            self.path = path
            self.isDirectory = isDirectory
        }
    }

    public var repoExists: Bool = true
    public var matches: [Match] = []
    public var fileCount: Int = 0
    public var directoryCount: Int = 0
    public var unmatchedPatterns: [String] = []
    public var isTruncated: Bool = false

    public init() {}
}

public enum FilesToCopyResolver {
    public static let defaultLimit = 200

    public static func resolve(
        patterns: [String],
        in repo: String,
        limit: Int = defaultLimit
    ) -> FilesToCopyPlan {
        var plan = FilesToCopyPlan()
        let manager = FileManager.default

        var isDirectory: ObjCBool = false
        guard manager.fileExists(atPath: repo, isDirectory: &isDirectory), isDirectory.boolValue else {
            plan.repoExists = false
            return plan
        }

        var seen = Set<String>()
        var found: [FilesToCopyPlan.Match] = []

        for pattern in patterns {
            let trimmed = pattern.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            let directory = (trimmed as NSString).deletingLastPathComponent
            let filePattern = (trimmed as NSString).lastPathComponent
            guard !(trimmed as NSString).isAbsolutePath,
                  !trimmed.split(separator: "/").contains("..") else {
                plan.unmatchedPatterns.append(trimmed)
                continue
            }
            let searchDirectory: String
            if directory.isEmpty || directory == "." {
                searchDirectory = repo
            } else if let contained = ContainedPath.relative(directory, inside: repo) {
                searchDirectory = contained.path
            } else {
                plan.unmatchedPatterns.append(trimmed)
                continue
            }

            guard let entries = try? manager.contentsOfDirectory(atPath: searchDirectory) else {
                plan.unmatchedPatterns.append(trimmed)
                continue
            }

            var matchedAnything = false
            for entry in entries where matches(entry, pattern: filePattern) {
                let relative = directory.isEmpty ? entry : "\(directory)/\(entry)"
                guard let absolute = ContainedPath.relative(relative, inside: repo)?.path else { continue }

                var entryIsDirectory: ObjCBool = false
                guard manager.fileExists(atPath: absolute, isDirectory: &entryIsDirectory) else { continue }
                matchedAnything = true
                guard seen.insert(relative).inserted else { continue }

                if entryIsDirectory.boolValue {
                    plan.directoryCount += 1
                    found.append(.init(path: relative, isDirectory: true))
                    continue
                }

                plan.fileCount += 1
                found.append(.init(path: relative, isDirectory: false))
            }

            if !matchedAnything { plan.unmatchedPatterns.append(trimmed) }
        }

        found.sort { $0.path < $1.path }
        plan.isTruncated = found.count > limit
        plan.matches = Array(found.prefix(limit))
        return plan
    }

    public static func matches(_ name: String, pattern: String) -> Bool {
        guard pattern.contains("*") || pattern.contains("?") else { return name == pattern }
        return fnmatch(pattern, name, 0) == 0
    }
}
