import SwiftUI
import Core

@MainActor
@Observable
final class FeedbackPresenter {
    static let shared = FeedbackPresenter()

    enum Sheet: String, Identifiable, CaseIterable {
        case report
        case prompt
        case reportSent
        case promptSent

        var id: String { rawValue }
    }

    var sheet: Sheet?

    var filed: IssueFilingOutcome?

    var message = ""
    var includesLogs = Feedback.includesLogs() {
        didSet { Feedback.rememberIncludesLogs(includesLogs) }
    }
    var logs = ""
    var images: [FeedbackImage] = []

    var prompt = ""

    private init() {}

    func open(_ sheet: Sheet) {
        self.sheet = sheet
    }

    func filedSentence(or fallback: String) -> String {
        filed.map(IssueFilingRoute.sentence(for:)) ?? fallback
    }

    func filedTitle(or fallback: String) -> String {
        switch filed {
        case .filed, .none: fallback
        case .page: Feedback.Copy.pageTitle
        case .refused: Feedback.Copy.refusedTitle
        }
    }

    var filedLink: URL? {
        filed.flatMap(IssueFilingRoute.link(for:))
    }

    func presentIfRequested() {
        #if DEBUG
        let arguments = CommandLine.arguments
        guard let request = Self.debugRequests.first(where: { arguments.contains($0.argument) })
        else { return }

        request.prepare(self)
        open(request.sheet)
        #endif
    }

    #if DEBUG
    private struct DebugRequest {
        let argument: String
        let sheet: Sheet
        let prepare: @MainActor (FeedbackPresenter) -> Void
    }

    private static let debugRequests: [DebugRequest] = [
        DebugRequest(argument: "--feedback-logs", sheet: .report) { presenter in
            presenter.fillMessage("Something went wrong while a workspace was finishing.")
            presenter.includesLogs = true
        },
        DebugRequest(argument: "--feedback-sheet", sheet: .report) { presenter in
            presenter.fillMessage(
                "The composer loses its place when a workspace finishes while I am typing in it."
            )
        },
        DebugRequest(argument: "--prompt-sheet", sheet: .prompt) { presenter in
            presenter.fillPrompt(
                "Give the sidebar a way to group workspaces by the project they came from."
            )
        },
        DebugRequest(argument: "--feedback-sent", sheet: .reportSent) { _ in },
        DebugRequest(argument: "--prompt-sent", sheet: .promptSent) { _ in },
    ]

    private func fillMessage(_ sample: String) {
        guard message.isEmpty else { return }
        message = sample
    }

    private func fillPrompt(_ sample: String) {
        guard prompt.isEmpty else { return }
        prompt = sample
    }
    #endif

    func close() {
        sheet = nil
        filed = nil
    }

    func clearReport() {
        message = ""
        logs = ""
        images = []
    }

    func clearPrompt() {
        prompt = ""
    }
}
