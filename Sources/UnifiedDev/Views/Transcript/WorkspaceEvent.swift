import SwiftUI
import Core

struct WorkspaceEvent: Identifiable, Equatable {
    enum Kind: String, Equatable {
        case setup
    }

    enum Outcome: Equatable {
        case running
        case succeeded
        case failed
        case skipped
        case ignored
    }

    var id = UUID().uuidString
    var kind: Kind
    var outcome: Outcome
    var title: String
    var detail: String = ""
    var note: String = ""
    var log: String = ""
    var failureSummary: String = ""
    var durationMS: Int?

    let logLines: Int

    init(
        id: String = UUID().uuidString,
        kind: Kind,
        outcome: Outcome,
        title: String,
        detail: String = "",
        note: String = "",
        log: String = "",
        failureSummary: String = "",
        durationMS: Int? = nil
    ) {
        self.id = id
        self.kind = kind
        self.outcome = outcome
        self.title = title
        self.detail = detail
        self.note = note
        self.log = log
        self.failureSummary = failureSummary
        self.durationMS = durationMS
        self.logLines = LogTail.lineCount(log)
    }

    var isRunning: Bool { outcome == .running }
    var isFailure: Bool { outcome == .failed }

    var presentation: ToolPresentation {
        ToolPresentation(glyph: glyph, label: title, detail: detail, tint: tint)
    }

    private var glyph: String {
        switch (kind, outcome) {
        case (.setup, .running): "gearshape.2"
        case (.setup, .succeeded): "checkmark.seal"
        case (.setup, .skipped), (.setup, .ignored): "gearshape.2"
        case (.setup, _): "exclamationmark.triangle"
        }
    }

    private var tint: ToolTint {
        switch outcome {
        case .running: .accent
        case .succeeded: .positive
        case .failed: .negative
        case .skipped, .ignored: .neutral
        }
    }

    static func setup(
        state: SetupState, log: String, durationMS: Int?, status: Int? = nil
    ) -> WorkspaceEvent? {
        switch state {
        case .pending:
            return nil

        case .running:
            return WorkspaceEvent(
                id: "setup", kind: .setup, outcome: .running,
                title: "Setting up", detail: LogTail.lastLine(log), log: log
            )

        case .succeeded:
            guard !log.isEmpty else { return nil }
            let lines = LogTail.lineCount(log)
            return WorkspaceEvent(
                id: "setup", kind: .setup, outcome: .succeeded,
                title: "Setup finished",
                detail: lines == 1 ? "1 line of output" : "\(lines) lines of output",
                log: log, durationMS: durationMS
            )

        case .failed:
            let diagnosis = SetupDiagnosis.read(log: log, status: status)
            return WorkspaceEvent(
                id: "setup", kind: .setup, outcome: .failed,
                title: diagnosis.title, detail: diagnosis.summary,
                note: [
                    diagnosis.sentence,
                    diagnosis.advice.isEmpty ? SetupFailure.instruction : SetupFailure.agentStarted,
                ]
                    .filter { !$0.isEmpty }
                    .joined(separator: " "),
                log: log, failureSummary: diagnosis.summary, durationMS: durationMS
            )

        case .ignored:
            let diagnosis = SetupDiagnosis.read(log: log, status: status)
            return WorkspaceEvent(
                id: "setup", kind: .setup, outcome: .ignored,
                title: "Setup failure ignored", detail: diagnosis.summary,
                log: log, durationMS: durationMS
            )

        case .skipped:
            guard !log.isEmpty else { return nil }
            return WorkspaceEvent(
                id: "setup", kind: .setup, outcome: .skipped,
                title: "Setup skipped", detail: LogTail.lastLine(log)
            )
        }
    }
}

enum SetupFailure {
    static let instruction =
        "The agent was started anyway. Check the setup output and run setup again."

    static let agentStarted = "The agent was started anyway."
}
