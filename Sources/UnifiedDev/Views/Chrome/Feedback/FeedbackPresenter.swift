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
    var name = ""

    var email = ""

    private init() {
        let sender = Feedback.rememberedSender()
        name = sender.name
        email = sender.email
    }

    func open(_ sheet: Sheet) {
        self.sheet = sheet
    }

    func filedSentence(or fallback: String) -> String {
        filed.map(IssueFilingRoute.sentence(for:)) ?? fallback
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
            presenter.fillEmail()
        },
        DebugRequest(argument: "--prompt-sheet", sheet: .prompt) { presenter in
            presenter.fillPrompt(
                "Give the sidebar a way to group workspaces by the project they came from."
            )
            presenter.fillEmail()
        },
        DebugRequest(argument: "--feedback-problems", sheet: .report) { presenter in
            presenter.fillMessage("The composer loses its place while I am typing.")
            presenter.email = FeedbackPresenter.sampleEmail
        },
        DebugRequest(argument: "--prompt-problems", sheet: .prompt) { presenter in
            presenter.fillPrompt("Group workspaces by the project they came from.")
            presenter.name = "you@example.com"
            presenter.email = FeedbackPresenter.sampleEmail
        },
        DebugRequest(argument: "--feedback-sent", sheet: .reportSent) { _ in },
        DebugRequest(argument: "--prompt-sent", sheet: .promptSent) { _ in },
    ]

    private static let sampleEmail = "you@example."

    private func fillMessage(_ sample: String) {
        guard message.isEmpty else { return }
        message = sample
    }

    private func fillPrompt(_ sample: String) {
        guard prompt.isEmpty else { return }
        prompt = sample
    }

    private func fillEmail() {
        guard email.isEmpty else { return }
        email = Self.sampleEmail
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
        Feedback.rememberSender(name: nil, email: email)
    }

    func clearPrompt() {
        prompt = ""
        Feedback.rememberSender(name: name, email: email)
    }
}
