import Foundation

public struct CanvasQuitQuestion: Sendable, Equatable {
    public let title: String
    public let detail: String

    public init?(stranded: [String], copiesOfOwnerWork: [String]) {
        guard !stranded.isEmpty || !copiesOfOwnerWork.isEmpty else { return nil }
        let unsaved = Self.paragraph(
            "Those edits have not reached the file, and quitting can lose them.", listing: stranded
        )
        let copied = Self.paragraph(
            "The file changed on disk, so your edits were kept beside it, in a copy. After quitting, nothing points to that copy.",
            listing: copiesOfOwnerWork
        )
        title = Self.title(stranded: stranded.count, copies: copiesOfOwnerWork.count)
        detail = [unsaved, copied].compactMap(\.self).joined(separator: "\n\n")
    }

    private static func title(stranded: Int, copies: Int) -> String {
        guard stranded == 0 else {
            return stranded == 1 ? "A canvas has edits that are not saved" : "\(stranded) canvases have edits that are not saved"
        }
        return copies == 1 ? "Your canvas edits are in a copy" : "Your canvas edits are in \(copies) copies"
    }

    private static func paragraph(_ sentence: String, listing paths: [String]) -> String? {
        guard !paths.isEmpty else { return nil }
        let names = paths.map { "\u{2022} \(($0 as NSString).lastPathComponent)" }.sorted().joined(separator: "\n")
        return "\(sentence)\n\n\(names)"
    }
}
