import SwiftUI
import Observation

enum TranscriptHoverCard: Equatable {
    case file(attachment: PromptAttachment, worktree: String)
    case instructions(title: String, body: String)
    case row(title: String, detail: String, isCode: Bool)

    var identity: String {
        switch self {
        case .file(let attachment, _): "file:" + attachment.path
        case .instructions(let title, let body): "instructions:" + title + "\u{0}" + body
        case .row(let title, let detail, let isCode):
            "row:" + title + "\u{0}" + detail + "\u{0}" + (isCode ? "code" : "prose")
        }
    }
}

struct TranscriptHoverRequest: Equatable {
    var card: TranscriptHoverCard
    var frame: CGRect
}

@MainActor
@Observable
final class TranscriptHoverHost {
    var request: TranscriptHoverRequest?
}

extension EnvironmentValues {
    @Entry var transcriptHoverHost: TranscriptHoverHost?
}
