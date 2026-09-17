import Foundation

public enum PullRequestHead {
    public static func branch(recorded: String, checkedOut: String?, base: String) -> String {
        let live = (checkedOut ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !live.isEmpty else { return recorded }
        guard !recorded.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return live }
        return live == base ? recorded : live
    }
}
