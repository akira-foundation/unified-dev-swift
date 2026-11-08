import Foundation

public enum ProfileFolder {
    public static func name(for profileName: String, taken: Set<String>) -> String {
        let lowered = Set(taken.map { $0.lowercased() })
        return firstFree(slug(profileName)) { lowered.contains($0.lowercased()) }
    }

    public static func usable(
        _ folder: String,
        under root: URL,
        recordedWorktrees: [String],
        otherProfiles: Set<String>,
        holdsWorktree: (URL) -> Bool = containsWorktree
    ) -> String {
        let projectDirectories = Set(recordedWorktrees.compactMap { projectDirectory(of: $0, under: root) })
        let others = Set(otherProfiles.map { $0.lowercased() })
        func isProjectDirectory(_ name: String) -> Bool {
            projectDirectories.contains(name.lowercased())
                || holdsWorktree(root.appendingPathComponent(name, isDirectory: true))
        }
        guard isProjectDirectory(folder) else { return folder }
        return firstFree(folder) { isProjectDirectory($0) || others.contains($0.lowercased()) }
    }

    public static func containsWorktree(_ directory: URL) -> Bool {
        guard (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) != nil else {
            return FileManager.default.fileExists(atPath: directory.path)
        }
        return !RepositoryStarter.childRepositories(of: directory.path).isEmpty
    }

    private static func firstFree(_ base: String, isTaken: (String) -> Bool) -> String {
        guard isTaken(base) else { return base }
        var number = 2
        while isTaken("\(base)-\(number)") { number += 1 }
        return "\(base)-\(number)"
    }

    private static func projectDirectory(of worktree: String, under root: URL) -> String? {
        let parts = URL(fileURLWithPath: worktree).standardized.pathComponents
        let rootParts = root.standardized.pathComponents
        guard parts.count == rootParts.count + 2, Array(parts.prefix(rootParts.count)) == rootParts else { return nil }
        return parts[rootParts.count].lowercased()
    }

    public static func occupied(under root: URL) -> Set<String> {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: root.path)) ?? []
        return Set(names)
    }

    private static func slug(_ name: String) -> String {
        let folded = name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        let mapped = folded.unicodeScalars.map { scalar -> Character in
            let isUsable = (scalar >= "a" && scalar <= "z") || (scalar >= "0" && scalar <= "9")
            return isUsable ? Character(scalar) : "-"
        }
        let parts = String(mapped).split(separator: "-", omittingEmptySubsequences: true)
        return parts.isEmpty ? "profile" : parts.joined(separator: "-")
    }
}
