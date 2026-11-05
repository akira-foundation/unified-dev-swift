import SwiftUI
import Core

struct SubagentOutputView: View {
    var model: WorkspaceModel
    var target: SubagentRunLink.Target
    var offersComposer = true
    var source: TranscriptModel?

    @State private var state = SubagentOutputState()
    @State private var position = ScrollPosition(edge: .bottom)
    @State private var followsEnd = true
    @State private var offersJump = false
    @State private var bubbleWidth = TranscriptBubbleWidth()
    @State private var hoverHost = TranscriptHoverHost()
    @State private var room = ComposerRoom()

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @AppStorage(ChatTextSize.defaultsKey) private var textSize = ChatTextSize.defaultChoice
    @AppStorage(ChatFont.defaultsKey) private var chatFontID = ChatFont.standardID
    @AppStorage(ChatLineHeight.defaultsKey) private var lineHeight = ChatLineHeight.defaultChoice

    private var output: SubagentOutputSource {
        SubagentOutputSource(model: model, target: target, source: source)
    }

    private var subagent: Subagent? { output.subagent }

    private var transcript: TranscriptModel? { output.transcript }

    private var reading: SubagentReading { state.reading }

    private var failure: SubagentOutput.Failure? { state.failure }

    private var home: TranscriptHome {
        transcript?.home ?? TranscriptHome(model.workspace)
    }

    var body: some View {
        VStack(spacing: 0) {
            reader
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if offersComposer, let parent = transcript?.session.id {
                ReviewPaneComposer(model: model, room: room, destinationID: parent)
            }
        }
        .onGeometryChange(for: CGFloat.self) { PaneMeasure.room($0.size.height) } action: {
            room.height = $0
        }
    }

    private var reader: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if let subagent {
                    header(subagent)
                        .subagentReadingColumn()

                    agentBody(subagent)
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
        await output.follow { result in
            var updated = state
            updated.apply(result)
            if updated != state { state = updated }
        }
    }

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

            if let summary = SubagentPane.distinctSummary(subagent), reading.rows.isEmpty, reading.printed.isEmpty {
                Text(summary)
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
}
