import Foundation

enum OrchestratorUnaskedGit {
    typealias Verdict = OrchestratorUnaskedVerdict

    private static let flagsTakingAWord: Set<String> = [
        "-C", "-c", "--git-dir", "--work-tree", "--namespace", "--super-prefix", "--config-env", "--attr-source",
    ]
    private static let flagsThatRedirectGit = ["-c", "--config-env", "--exec-path", "--git-dir", "--work-tree", "--namespace"]
    private static let reads: Set<String> = [
        "status", "log", "diff", "show", "blame", "shortlog", "describe", "rev-parse", "rev-list", "ls-files", "ls-tree",
        "ls-remote", "merge-base", "cat-file", "grep", "for-each-ref", "show-ref", "name-rev", "whatchanged", "fetch",
        "count-objects", "diff-tree", "cherry", "check-ignore", "var", "version",
    ]
    private static let flagsThatWriteOrRun = [
        "--output", "-O", "--open-files-in-pager", "--upload-pack", "--receive-pack", "--exec", "--ext-diff", "--no-index",
    ]
    private static let fetchFlagsThatMoveBranches = ["--prune", "--update-head-ok", "--force"]
    private static let fetchShortFlagsThatMoveBranches = "pPuf"
    private static let lsRemoteShortFlagsThatRun = "u"

    private static let ghReadVerbs: [String: Set<String>] = [
        "pr": ["view", "list", "status", "diff", "checks"],
        "issue": ["view", "list", "status"],
        "run": ["view", "list", "watch"],
        "repo": ["view", "list"],
        "release": ["view", "list"],
        "workflow": ["view", "list"],
        "label": ["list"],
    ]
    private static let ghCommandsThatOnlyRead: Set<String> = ["search", "api", "status"]
    private static let ghWritingFlags = ["--method", "--field", "--raw-field", "--input"]
    private static let ghWritingShortFlags = "XFf"
    private static let ghVerbsWhereShortWIsNotTheBrowser: Set<String> = ["run list"]

    static func verdict(_ arguments: [String]) -> Verdict {
        var index = 0
        while index < arguments.count, arguments[index].hasPrefix("-") {
            index += flagsTakingAWord.contains(arguments[index]) ? 2 : 1
        }
        guard index < arguments.count, OrchestratorUnaskedJudge.isSimple(arguments[index]) else { return .asks }
        let verb = arguments[index]
        if OrchestratorShellJudge.gitVerbs.contains(verb) { return .refused }
        let global = arguments[..<index]
        if global.contains(where: { flag in flagsThatRedirectGit.contains { flag == $0 || flag.hasPrefix("\($0)=") } }) {
            return .asks
        }
        guard reads.contains(verb) else {
            return OrchestratorReadList.contains(["git"] + arguments) ? .passes : .asks
        }
        let after = Array(arguments[(index + 1)...])
        if verb == "fetch", after.contains(where: movesBranches) { return .asks }
        if verb == "ls-remote", after.contains(where: { OrchestratorUnaskedPrograms.hasShortFlag($0, in: lsRemoteShortFlagsThatRun) }) {
            return .asks
        }
        return after.contains { word in
            OrchestratorUnaskedPrograms.names(word, oneOf: flagsThatWriteOrRun) || OrchestratorUnaskedPrograms.hasShortFlag(word, in: "O")
        } ? .asks : .passes
    }

    private static func movesBranches(_ word: String) -> Bool {
        word.contains(":") || word.hasPrefix("+") || OrchestratorUnaskedPrograms.names(word, oneOf: fetchFlagsThatMoveBranches)
            || OrchestratorUnaskedPrograms.hasShortFlag(word, in: fetchShortFlagsThatMoveBranches)
    }

    static func ghVerdict(_ arguments: [String]) -> Verdict {
        let positional = arguments.filter { !$0.hasPrefix("-") }
        guard let command = positional.first else { return .passes }
        let changesTheBranch = positional.contains("merge") || positional.contains("checkout")
        if arguments.prefix(2).contains(where: { $0.hasPrefix("-") }) {
            return positional.contains("pr") && changesTheBranch ? .refused : .asks
        }
        guard positional.prefix(2).allSatisfy(OrchestratorUnaskedJudge.isSimple) else { return .asks }
        let verb = positional.count > 1 ? positional[1] : ""
        if command == "pr", ["merge", "checkout"].contains(verb) { return .refused }
        guard ghCommandsThatOnlyRead.contains(command) || ghReadVerbs[command]?.contains(verb) == true else { return .asks }
        let shortWIsTheBrowser = !ghVerbsWhereShortWIsNotTheBrowser.contains("\(command) \(verb)")
        if arguments.contains(where: { opensABrowser($0, shortWIsTheBrowser: shortWIsTheBrowser) }) { return .asks }
        let writes = command == "api" && arguments.contains { word in
            word.contains("$") || OrchestratorUnaskedPrograms.names(word, oneOf: ghWritingFlags)
                || OrchestratorUnaskedPrograms.hasShortFlag(word, in: ghWritingShortFlags)
        }
        return writes ? .asks : .passes
    }

    private static func opensABrowser(_ word: String, shortWIsTheBrowser: Bool) -> Bool {
        OrchestratorUnaskedPrograms.names(word, oneOf: ["--web"])
            || (shortWIsTheBrowser && OrchestratorUnaskedPrograms.hasShortFlag(word, in: "w"))
    }
}
