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

    func presentIfRequested() {
        #if DEBUG
        let arguments = CommandLine.arguments
        if arguments.contains("--feedback-logs") {
            if message.isEmpty { message = "Something went wrong while a workspace was finishing." }
            includesLogs = true
            open(.report)
        } else if arguments.contains("--feedback-sheet") {
            if message.isEmpty {
                message = "The composer loses its place when a workspace finishes while I am typing in it."
            }
            if email.isEmpty { email = "you@example." }
            open(.report)
        } else if arguments.contains("--prompt-sheet") {
            if prompt.isEmpty {
                prompt = "Give the sidebar a way to group workspaces by the project they came from."
            }
            if email.isEmpty { email = "you@example." }
            open(.prompt)
        } else if arguments.contains("--feedback-problems") {
            if message.isEmpty { message = "The composer loses its place while I am typing." }
            email = "you@example."
            open(.report)
        } else if arguments.contains("--prompt-problems") {
            if prompt.isEmpty { prompt = "Group workspaces by the project they came from." }
            name = "you@example.com"
            email = "you@example."
            open(.prompt)
        } else if arguments.contains("--feedback-sent") {
            open(.reportSent)
        } else if arguments.contains("--prompt-sent") {
            open(.promptSent)
        }
        #endif
    }

    func close() {
        sheet = nil
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
