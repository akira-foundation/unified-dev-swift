import SwiftUI
import Core

struct SubagentOutputView: View {
    var model: WorkspaceModel
    var target: SubagentRunLink.Target

    @State private var reading = SubagentReading()
    @State private var failure: SubagentOutput.Failure?
    @State private var isBriefExpanded = false
    @State private var position = ScrollPosition(edge: .bottom)
    @State private var followsEnd = true
    @State private var offersJump = false
    @State private var bubbleWidth = TranscriptBubbleWidth()
    @State private var hoverHost = TranscriptHoverHost()

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
            LazyVStack(alignment: .leading, spacing: 0) {
                if let subagent {
                    header(subagent)
                        .subagentReadingColumn()

                    switch subagent.kind {
                    case .agent: agentBody(subagent)
                    case .command: commandBody(subagent)
                    }
                } else {
                    Text(missingSentence)
                        .font(Typo.body)
                        .foregroundStyle(Palette.textSecondary)
                        .padding(.horizontal, TranscriptLayout.inset)
                        .subagentReadingColumn()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, Metrics.pane)
        }
        .scrollPosition($position)
        .defaultScrollAnchor(.bottom, for: .initialOffset)
        .onScrollGeometryChange(for: Bool.self) { geometry in
            ScrollEnd.isAtEnd(
                contentHeight: geometry.contentSize.height,
                viewportHeight: geometry.containerSize.height,
                offset: geometry.contentOffset.y
            )
        } action: { _, atEnd in
            followsEnd = atEnd
        }
        .onScrollGeometryChange(for: Bool.self) { geometry in
            ScrollEnd.isWorthOffering(
                contentHeight: geometry.contentSize.height,
                viewportHeight: geometry.containerSize.height,
                offset: geometry.contentOffset.y
            )
        } action: { _, worthOffering in
            offersJump = worthOffering
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            TranscriptGeometry.cap(
                width: proxy.size.width,
                share: TranscriptListView.bubbleShare,
                gutter: Metrics.gutter,
                floor: TranscriptListView.bubbleFloor
            )
        } action: { cap in
            if bubbleWidth.cap != cap { bubbleWidth.cap = cap }
        }
        .overlay { TranscriptHoverOverlay(host: hoverHost) }
        .overlay(alignment: .bottom) {
            if offersJump, !followsEnd {
                JumpToNewestPill(action: jumpToNewest)
                    .padding(.bottom, Metrics.pane)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 4)))
            }
        }
        .animation(reduceMotion ? nil : Motion.pane, value: offersJump && !followsEnd)
        .environment(\.transcriptHoverHost, hoverHost)
        .environment(\.transcriptBubbleWidth, bubbleWidth)
        .environment(\.fontScale, textSize.scale)
        .environment(\.chatFont, ChatFont(rawValue: chatFontID))
        .environment(\.chatLineHeight, lineHeight)
        .markdownLinkActions(TranscriptLink.actions(for: model))
        .onChange(of: reading) { _, _ in
            guard followsEnd else { return }
            position.scrollTo(edge: .bottom)
        }
        .onChange(of: target) { _, _ in
            isBriefExpanded = false
            jumpToNewest()
        }
        .task(id: "\(target):\(SubagentPane.refreshes(subagent))") { await follow() }
    }

    private func jumpToNewest() {
        followsEnd = true
        position.scrollTo(edge: .bottom)
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
            if updated != reading { reading = updated }
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
            if parsed != reading { reading = parsed }
            failure = nil
        case .failure(let reason):
            if reading != SubagentReading() { reading = SubagentReading() }
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

            if !subagent.summary.isEmpty, reading.rows.isEmpty, reading.printed.isEmpty {
                Text(subagent.summary)
                    .font(Typo.body)
                    .textSelection(.enabled)
            }
        }
        .padding(.horizontal, TranscriptLayout.inset)
        .padding(.bottom, TranscriptLayout.block)
    }

    @ViewBuilder
    private func agentBody(_ subagent: Subagent) -> some View {
        let isRunning = subagent.state == .running
        SubagentConversationView(
            rows: reading.rows,
            prompt: subagent.prompt.isEmpty ? reading.prompt : subagent.prompt,
            home: home,
            droppedRows: reading.droppedRows,
            isRunning: isRunning
        )
        .id(target)

        if let failure, !isRunning {
            Text(SubagentPane.nothingToShow(failure, kind: .agent, isRunning: false))
                .font(Typo.body)
                .foregroundStyle(Palette.textSecondary)
                .padding(.horizontal, TranscriptLayout.inset)
                .subagentReadingColumn()
        }
    }

    @ViewBuilder
    private func commandBody(_ subagent: Subagent) -> some View {
        let command = model.commandLine(forToolUseID: subagent.toolUseID) ?? ""
        if !command.isEmpty {
            VStack(alignment: .leading, spacing: Metrics.spacingSmall) {
                caption(SubagentPane.briefLabel(.command))
                if SubagentPane.briefCollapses(command) {
                    Button(TextFold.title(isExpanded: isBriefExpanded)) {
                        isBriefExpanded.toggle()
                    }
                    .linkButton()
                    .font(Typo.caption)
                }
                if !SubagentPane.briefCollapses(command) || isBriefExpanded {
                    DetailCodeBlock(text: command, copyTitle: "Copy the command")
                }
            }
            .padding(.horizontal, TranscriptLayout.inset)
            .padding(.bottom, TranscriptLayout.block)
            .subagentReadingColumn()
        }

        Group {
            if let failure {
                Text(SubagentPane.nothingToShow(
                    failure, kind: .command, isRunning: subagent.state == .running
                ))
                .font(Typo.body)
                .foregroundStyle(Palette.textSecondary)
            }
            if failure == nil, !reading.printed.isEmpty {
                VStack(alignment: .leading, spacing: Metrics.spacingSmall) {
                    caption(SubagentPane.outputLabel(.command))
                    DetailCodeBlock(text: reading.printed, copyTitle: "Copy the output")
                }
            }
        }
        .padding(.horizontal, TranscriptLayout.inset)
        .subagentReadingColumn()
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
