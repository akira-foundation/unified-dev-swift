import Observation
import Core

@MainActor
@Observable
final class ReviewTextHost {
    var drafts: [String: String] = [:]

    var edits: [ReviewCommentID: String] = [:]
}
