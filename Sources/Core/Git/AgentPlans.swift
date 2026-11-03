import Foundation

enum AgentPlans {
    static let folder = "docs/superpowers/"

    static func mayHoldPlans(_ ignoredPath: String, worktree: String) -> Bool {
        if ignoredPath.hasPrefix(folder) { return true }
        guard folder.hasPrefix(ignoredPath) else { return false }
        return FileManager.default.fileExists(atPath: (worktree as NSString).appendingPathComponent(folder))
    }

    static func keepable(among paths: [String], worktree: String, repo: String) async throws -> Set<String> {
        let plans = paths.filter { $0.hasPrefix(folder) }
        return try await Git.checkIgnoredPaths(among: plans, in: repo).filter { path in
            isRegularFile((worktree as NSString).appendingPathComponent(path))
        }
    }

    static func collides(_ here: String, _ there: String) -> Bool {
        FileManager.default.fileExists(atPath: there) && Git.fileDiffers(here, there)
    }

    static func keep(worktree: String, repo: String, acceptingLoss: Bool) async throws -> Bool {
        let plans = try await Git.ignoredWork(worktree: worktree).filter { $0.hasPrefix(folder) }
        let copyable = try await keepable(among: plans, worktree: worktree, repo: repo)

        func locations(_ path: String) -> (here: String, there: String) {
            ((worktree as NSString).appendingPathComponent(path), (repo as NSString).appendingPathComponent(path))
        }

        let wouldLose = plans.contains { path in
            let (here, there) = locations(path)
            return copyable.contains(path) ? collides(here, there) : Git.fileDiffers(here, there)
        }
        if wouldLose, !acceptingLoss { return false }

        for path in copyable {
            let (here, there) = locations(path)
            guard !FileManager.default.fileExists(atPath: there) else { continue }
            try FileManager.default.createDirectory(
                atPath: (there as NSString).deletingLastPathComponent,
                withIntermediateDirectories: true
            )
            try copyWhole(here, to: there)
        }
        return true
    }

    private static func copyWhole(_ here: String, to there: String) throws {
        let partial = "\(there).\(UUID().uuidString).partial"
        do {
            try FileManager.default.copyItem(atPath: here, toPath: partial)
            try FileManager.default.moveItem(atPath: partial, toPath: there)
        } catch {
            try? FileManager.default.removeItem(atPath: partial)
            throw error
        }
    }

    private static func isRegularFile(_ path: String) -> Bool {
        let attributes = try? FileManager.default.attributesOfItem(atPath: path)
        return attributes?[.type] as? FileAttributeType == .typeRegular
    }
}
