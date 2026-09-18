import SwiftUI
import Core

struct SubagentOutputView: View {
    var model: WorkspaceModel
    var target: SubagentRunLink.Target

    @State private var reading = SubagentReading()
    @State private var failure: SubagentOutput.Failure?
    @State private var isBriefExpanded = false

    @AppStorage(ChatTextSize.defaultsKey) private var textSize = ChatTextSize.defaultChoice
    @AppStorage(ChatFont.defaultsKey) private var chatFontID = ChatFont.standardID
    @AppStorage(ChatLineHeight.defaultsKey) private var lineHeight = ChatLineHeight.defaultChoice

    private var subagent: Subagent? {
        let roster = model.activeTranscript?.subagents
        switch target {
        case let .live(id):
            return roster?[id]
        case let .recorded(toolUseID):
            return roster?.subagent(forToolUseID: toolUseID)
                ?? model.recordedSubagent(forToolUseID: toolUseID)
        case .unavailable:
            return nil
        }
    }

    private var kind: SubagentKind { subagent?.kind ?? .agent }

    private var home: TranscriptHome {
        model.activeTranscript?.home ?? TranscriptHome(model.workspace)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let subagent {
                    header(subagent)
                    brief(subagent)
                } else {
                    Text(missingSentence)
                        .font(Typo.body)
                        .foregroundStyle(Palette.textSecondary)
                        .padding(.horizontal, TranscriptLayout.inset)
                }

                output
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, Metrics.pane)
        }
        .environment(\.fontScale, textSize.scale)
        .environment(\.chatFont, ChatFont(rawValue: chatFontID))
        .environment(\.chatLineHeight, lineHeight)
        .markdownLinkActions(TranscriptLink.actions(for: model))
        .onChange(of: target) { _, _ in isBriefExpanded = false }
        .task(id: "\(target):\(SubagentPane.refreshes(subagent))") { await follow() }
    }

    private var missingSentence: String {
        if case .recorded = target {
            return "That agent's run is not in the chat that is open now."
        }
        return "That subagent belonged to a turn that has since been replaced."
    }

    private func follow() async {
        await load()
        while !Task.isCancelled, SubagentPane.refreshes(subagent) {
            try? await Task.sleep(for: .seconds(SubagentPane.refreshSeconds))
            guard !Task.isCancelled else { return }
            await load()
        }
        await load()
    }

    private func load() async {
        if case let .live(id) = target,
           let parsed = await model.activeTranscript?.codexSubagentTranscript(for: id) {
            guard !Task.isCancelled else { return }
            let updated = await Task.detached { SubagentReading(parsed) }.value
            guard !Task.isCancelled else { return }
            reading = updated
            failure = nil
            return
        }
        let path = subagent?.outputFile
        let kind = kind
        let session = model.activeTranscript?.session.id ?? SessionID("")
        let lines = kind == .agent ? model.subagentStreamLines(forToolUseID: toolUseID) : []
        let result = await Task.detached { () -> Result<SubagentReading, SubagentOutput.Failure> in
            switch SubagentOutput.read(path: path, kind: kind, sessionID: session) {
            case .success(let parsed):
                return .success(SubagentReading(parsed))
            case .failure(let reason):
                let live = SubagentTranscript.live(streamLines: lines, sessionID: session)
                return live.isEmpty ? .failure(reason) : .success(SubagentReading(live))
            }
        }.value
        guard !Task.isCancelled else { return }
        switch result {
        case .success(let parsed):
            reading = parsed
            failure = nil
        case .failure(let reason):
            reading = SubagentReading()
            failure = reason
        }
    }

    private var toolUseID: String { subagent?.toolUseID ?? "" }

    private func header(_ subagent: Subagent) -> some View {
        VStack(alignment: .leading, spacing: Metrics.spacingSmall) {
            HStack(spacing: Metrics.spacingSmall) {
                SubagentMarkGlyph(mark: SubagentRow(subagent).mark)
                Text(SubagentRow.title(of: subagent))
                    .font(Typo.title)
            }

            Text(SubagentPane.subtitle(subagent))
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)

            if !subagent.summary.isEmpty {
                Text(subagent.summary)
                    .font(Typo.body)
                    .textSelection(.enabled)
            }
        }
        .padding(.horizontal, TranscriptLayout.inset)
        .padding(.bottom, TranscriptLayout.block)
    }

    @ViewBuilder
    private func brief(_ subagent: Subagent) -> some View {
        let text = briefText(subagent)
        if !text.isEmpty {
            let collapses = SubagentPane.briefCollapses(text)
            VStack(alignment: .leading, spacing: Metrics.spacingSmall) {
                caption(SubagentPane.briefLabel(subagent.kind))
                    .padding(.horizontal, TranscriptLayout.inset)

                if collapses {
                    Button(SubagentPane.briefToggle(isExpanded: isBriefExpanded, kind: subagent.kind)) {
                        isBriefExpanded.toggle()
                    }
                    .buttonStyle(.link)
                    .font(Typo.caption)
                    .padding(.horizontal, TranscriptLayout.inset)
                }

                if !collapses || isBriefExpanded {
                    if SubagentPane.briefIsCode(subagent.kind) {
                        DetailCodeBlock(text: text, copyTitle: "Copy the command")
                            .padding(.horizontal, TranscriptLayout.inset)
                    } else {
                        ProseRowView(text: text)
                    }
                }
            }
            .padding(.bottom, TranscriptLayout.block)
        }
    }

    private func briefText(_ subagent: Subagent) -> String {
        switch subagent.kind {
        case .agent: subagent.prompt.isEmpty ? reading.prompt : subagent.prompt
        case .command: model.commandLine(forToolUseID: subagent.toolUseID) ?? ""
        }
    }

    @ViewBuilder
    private var output: some View {
        switch (failure, reading.printed.isEmpty) {
        case (.some(let failure), _):
            Text(SubagentPane.nothingToShow(
                failure, kind: kind, isRunning: subagent?.state == .running
            ))
                .font(Typo.body)
                .foregroundStyle(Palette.textSecondary)
                .padding(.horizontal, TranscriptLayout.inset)
        case (.none, false):
            VStack(alignment: .leading, spacing: Metrics.spacingSmall) {
                caption(SubagentPane.outputLabel(.command))
                DetailCodeBlock(text: reading.printed, copyTitle: "Copy the output")
            }
            .padding(.horizontal, TranscriptLayout.inset)
        case (.none, true):
            SubagentConversationView(
                rows: reading.rows, home: home, droppedRows: reading.droppedRows
            )
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text.uppercased())
            .font(Typo.micro)
            .tracking(Typo.microTracking)
            .foregroundStyle(Palette.textTertiary)
    }
}

private struct SubagentReading: Equatable, Sendable {
    var rows: [TranscriptRow] = []
    var droppedRows = 0
    var printed = ""
    var prompt = ""

    init() {}

    init(_ transcript: SubagentTranscript) {
        rows = TranscriptModel.rows(from: transcript.messages)
        droppedRows = transcript.droppedRows
        printed = transcript.printed
        prompt = transcript.prompt
    }
}
