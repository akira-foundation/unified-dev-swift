import Foundation

public struct CanvasArchiveQuestion: Sendable, Equatable {
    public let losses: [String]

    public init?(stranded: [String], copiesOfOwnerWork: [String]) {
        guard !stranded.isEmpty || !copiesOfOwnerWork.isEmpty else { return nil }
        losses = stranded.map { "the canvas edits in \(CanvasQuitQuestion.name(of: $0)), which have not reached the file" }
            + copiesOfOwnerWork.map { "your canvas edits, which are only in the copy \(CanvasQuitQuestion.name(of: $0)) beside the canvas" }
    }

    public static func asks(_ losses: [String], acknowledged: [String]) -> Bool {
        !Set(losses).isSubset(of: acknowledged)
    }

    public var refusal: String {
        "Removing it would lose:\n" + losses.map { "\u{2022} \($0)" }.joined(separator: "\n")
            + "\n\nGo back to the canvas, or remove the project again to lose them."
    }
}
