import Foundation

public struct BranchKeptNotice: Sendable, Hashable {
    public var title: String
    public var reason: [NoticeRun]

    public static func make(refusal: BranchRenameRefusal) -> BranchKeptNotice? {
        guard refusal.isWorthReporting else { return nil }
        let sentence = refusal.reason.prefix(1).uppercased() + refusal.reason.dropFirst() + "."
        return BranchKeptNotice(
            title: "The branch was not renamed",
            reason: NoticeText.runs(in: sentence)
        )
    }
}
