import Foundation

public extension PreviewScenario {
    var problems: [String] {
        var problems: [String] = []
        if projects.isEmpty { problems.append("the scenario names no projects") }
        var seen = Set<String>()
        for project in projects {
            let name = project.name
            if !Self.isFolderName(name) {
                problems.append("project \"\(name)\" is not a plain folder name")
            }
            if !seen.insert(name.lowercased()).inserted {
                problems.append("project \"\(name)\" is named twice")
            }
            for path in project.files.keys where !Self.isRelativeFile(path) {
                problems.append("project \"\(name)\" writes \"\(path)\", which is not a path inside the project")
            }
            var branches = Set<String>()
            var startedSoFar: Set<String> = []
            for workspace in project.workspaces {
                defer { startedSoFar.insert(workspace.name) }
                if startedSoFar.contains(workspace.name) {
                    problems.append("workspace \"\(workspace.name)\" is named twice in \"\(name)\"")
                }
                if let starter = workspace.startedBy, starter == workspace.name {
                    problems.append("workspace \"\(workspace.name)\" in \"\(name)\" is started by itself")
                }
                if let starter = workspace.startedBy, starter != workspace.name,
                   !startedSoFar.contains(starter) {
                    problems.append(
                        "workspace \"\(workspace.name)\" in \"\(name)\" is started by \"\(starter)\", "
                            + "which is not a workspace listed before it in the same project"
                    )
                }
                if workspace.name.trimmingCharacters(in: .whitespaces).isEmpty {
                    problems.append("a workspace in \"\(name)\" has no name")
                }
                if !Git.isValidBranchName(workspace.branch) || workspace.branch == "main" {
                    problems.append("workspace \"\(workspace.name)\" in \"\(name)\" has an unusable branch \"\(workspace.branch)\"")
                }
                if !branches.insert(workspace.branch).inserted {
                    problems.append("branch \"\(workspace.branch)\" is used twice in \"\(name)\"")
                }
                for path in workspace.changes.keys where !Self.isRelativeFile(path) {
                    problems.append("workspace \"\(workspace.name)\" in \"\(name)\" changes \"\(path)\", which is not a path inside the worktree")
                }
                if let browser = workspace.browser, BrowserAddress.url(from: browser) == nil {
                    problems.append("workspace \"\(workspace.name)\" in \"\(name)\" opens \"\(browser)\", which is not an address")
                }
                if !(0...Workspace.spareFileCeiling).contains(workspace.spareFiles) {
                    problems.append(
                        "workspace \"\(workspace.name)\" in \"\(name)\" asks for \(workspace.spareFiles) "
                            + "spareFiles, and the preview seeds between 0 and \(Workspace.spareFileCeiling)"
                    )
                }
            }
            if !project.remote.exists, !project.remoteAhead.isEmpty {
                problems.append(
                    "project \"\(name)\" has no remote, so nothing can be ahead of one"
                )
            }
            for branch in project.branches {
                if !Git.isValidBranchName(branch) || branch == "main" {
                    problems.append("branch \"\(branch)\" in \"\(name)\" is unusable")
                }
                if !branches.insert(branch).inserted {
                    problems.append("branch \"\(branch)\" is used twice in \"\(name)\"")
                }
            }
            for branch in branches.sorted() where branches.contains(where: { branch.hasPrefix($0 + "/") }) {
                problems.append("branch \"\(branch)\" in \"\(name)\" sits under another branch of the scenario, which git cannot hold")
            }
        }
        problems += suggestionProblems
        problems += quotaProblems
        problems += recentProblems
        return problems
    }

    internal static func isFolderName(_ name: String) -> Bool {
        guard !name.isEmpty, name.count <= 64, !name.hasPrefix(".") else { return false }
        return name.unicodeScalars.allSatisfy {
            CharacterSet.alphanumerics.contains($0) && $0.isASCII || $0 == "-" || $0 == "_" || $0 == "."
        }
    }

    internal static func isRelativeFile(_ path: String) -> Bool {
        guard !path.isEmpty, !path.hasPrefix("/") else { return false }
        let parts = path.split(separator: "/", omittingEmptySubsequences: false)
        return parts.allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." && $0.lowercased() != ".git" }
    }
}
