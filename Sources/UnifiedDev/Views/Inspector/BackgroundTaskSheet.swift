import SwiftUI
import Core

struct BackgroundTaskSheet: View {
    let model: WorkspaceModel
    let transcript: TranscriptModel?
    let id: SubagentID

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            content
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
        .frame(minWidth: 560, idealWidth: 680, minHeight: 360, idealHeight: 520)
    }

    @ViewBuilder
    private var content: some View {
        if transcript?.subagents.task(id)?.kind == .command {
            BackgroundCommandDetail(model: model, transcript: transcript, id: id)
        } else {
            SubagentOutputView(model: model, target: .live(id), offersComposer: false, source: transcript)
        }
    }
}

private struct BackgroundCommandDetail: View {
    let model: WorkspaceModel
    let transcript: TranscriptModel?
    let id: SubagentID

    @State private var state = SubagentOutputState()

    private var output: SubagentOutputSource {
        SubagentOutputSource(model: model, target: .live(id), source: transcript)
    }

    var body: some View {
        let subagent = output.subagent
        Group {
            if let subagent {
                BackgroundCommandForm(
                    subagent: subagent,
                    command: model.commandLine(forToolUseID: subagent.toolUseID, in: transcript) ?? "",
                    printed: state.reading.printed,
                    failure: state.failure,
                    hasRead: state.hasRead
                )
            }
        }
        .task(id: SubagentPane.refreshes(subagent)) {
            await output.follow { result in
                var updated = state
                updated.apply(result)
                if updated != state { state = updated }
            }
        }
    }
}

struct BackgroundCommandForm: View {
    var subagent: Subagent
    var command: String
    var printed: String
    var failure: SubagentOutput.Failure?
    var hasRead: Bool

    private var isRunning: Bool { subagent.state == .running }

    var body: some View {
        Form {
            summarySection

            if !command.isEmpty {
                Section("Command") {
                    DetailCodeBlock(text: command, tint: .clear, copyTitle: "Copy the command")
                }
            }

            if hasRead {
                Section("Output") {
                    if failure == nil, !printed.isEmpty {
                        DetailCodeBlock(text: printed, tint: .clear, copyTitle: "Copy the output")
                    } else {
                        Text(SubagentPane.commandOutputNote(failure: failure, isRunning: isRunning))
                            .font(Typo.body)
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .hidesScrollEdgeRule()
    }

    private var summarySection: some View {
        Section {
            TimelineView(.periodic(from: .now, by: isRunning ? 1 : 3600)) { context in
                ForEach(SubagentPane.facts(subagent, now: context.date)) { fact in
                    LabeledContent(fact.label, value: fact.value)
                        .monospacedDigit()
                }
            }
            if printed.isEmpty, let summary = SubagentPane.distinctSummary(subagent) {
                Text(summary)
                    .font(Typo.body)
                    .textSelection(.enabled)
            }
        } header: {
            HStack(alignment: .firstTextBaseline, spacing: Metrics.spacingSmall) {
                SubagentMarkGlyph(mark: SubagentRow(subagent).mark)
                Text(SubagentRow.title(of: subagent))
                    .font(Typo.title)
                    .foregroundStyle(Palette.textPrimary)
            }
            .padding(.bottom, Metrics.spacingSmall)
        }
    }
}
