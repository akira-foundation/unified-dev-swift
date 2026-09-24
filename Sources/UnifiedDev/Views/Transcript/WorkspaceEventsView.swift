import SwiftUI
import Core

struct WorkspaceEventsView: View, Equatable {
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.workspaceID == rhs.workspaceID
            && lhs.isRunning == rhs.isRunning
            && lhs.isFirstThing == rhs.isFirstThing
            && lhs.paneHeight == rhs.paneHeight
            && lhs.isSetupExpanded == rhs.isSetupExpanded
    }

    var workspaceID: WorkspaceID
    var isRunning: Bool
    var isFirstThing: Bool
    var paneHeight: CGFloat = 0
    var onVisibilityChange: (@MainActor (Bool) -> Void)?
    var onShowLogEnd: (@MainActor (Bool) -> Void)?
    var setupExpansion: Binding<Bool>?
    var isSetupExpanded = false

    @Environment(AppModel.self) private var app

    private var model: WorkspaceModel? { app.existingModel(for: workspaceID) }

    private var events: [WorkspaceEvent] {
        guard let model else { return [] }
        return model.timeline(isRunningSetup: isRunning)
    }

    var body: some View {
        let events = events

        Group {
            ForEach(events) { event in
                WorkspaceEventRow(
                    event: event,
                    isFirstThing: isFirstThing,
                    paneHeight: paneHeight,
                    model: model,
                    onShowLogEnd: onShowLogEnd,
                    expansion: event.kind == .setup ? setupExpansion : nil
                )
            }
        }
        .onChange(of: events.isEmpty, initial: true) { _, isEmpty in
            onVisibilityChange?(!isEmpty)
        }
    }
}

struct WorkspaceEventRow: View {
    var event: WorkspaceEvent
    var isFirstThing: Bool
    var paneHeight: CGFloat = 0
    var model: WorkspaceModel?
    var onShowLogEnd: (@MainActor (Bool) -> Void)?
    var expansion: Binding<Bool>?

    @State private var localExpansion = false

    private var isExpanded: Bool {
        get { expansion?.wrappedValue ?? localExpansion }
        nonmutating set {
            guard let expansion else {
                localExpansion = newValue
                return
            }
            expansion.wrappedValue = newValue
        }
    }

    @State private var isHovered = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.fontScale) private var fontScale

    private var tailCap: Int {
        SetupTailWindow.cap(paneHeight: Double(paneHeight), lineHeight: Double(lineHeight))
    }

    private var runningTail: Int {
        SetupTailWindow.lines(cap: tailCap, logLines: event.logLines)
    }

    private var failedTail: Int { SetupTailWindow.failureLines(cap: tailCap) }

    private static let expandedTail = TextCap.lineCap

    var body: some View {
        let tail = tail

        VStack(alignment: .leading, spacing: 0) {
            if canExpand {
                ExpandableRowHeader(isExpanded: isExpanded, onToggle: { isExpanded.toggle() }) {
                    header
                }
            } else {
                header
            }

            if !tail.isEmpty {
                logBlock(tail)
            }

            if !note.isEmpty {
                Text(note)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, TranscriptLayout.detailIndent)
                    .padding(.trailing, TranscriptLayout.inset)
                    .padding(.bottom, TranscriptLayout.block)
            }

            if event.kind == .setup {
                Color.clear.frame(height: 0).id(Self.endID)
            }
        }
        .modifier(ExpandableRow(isHovered: isHovered))
        .onHover { isHovered = $0 }
        .onChange(of: isExpanded) { _, isExpanded in
            guard isExpanded, event.kind == .setup else { return }
            showLogEnd(wasAsked: true)
        }
        .onChange(of: event.log.utf8.count) { _, _ in
            guard isExpanded, event.isRunning, event.kind == .setup else { return }
            showLogEnd(wasAsked: false)
        }
        .acceptsCaptureSetupLogExpansion {
            guard event.kind == .setup, canExpand else { return }
            isExpanded = true
        }
    }

    static let endID = "unifieddev.workspaceEvent.setupEnd"

    private func showLogEnd(wasAsked: Bool) {
        Task { @MainActor in
            await Task.yield()
            onShowLogEnd?(wasAsked)
        }
    }

    private var header: some View {
        ToolRowHeader(
            presentation: event.presentation,
            home: model.map { TranscriptHome($0.workspace) } ?? TranscriptHome(),
            isError: event.isFailure,
            durationMS: event.durationMS,
            isExpanded: isExpanded,
            isHovered: isHovered,
            showsDisclosure: canExpand
        )
    }

    private var canExpand: Bool { !event.log.isEmpty }

    private var note: String {
        if event.isRunning, isFirstThing, event.kind == .setup {
            return "You can ask for something now. It goes as soon as setup finishes."
        }
        return event.note
    }

    private var tail: String {
        guard !event.log.isEmpty else { return "" }
        if isExpanded { return LogTail.last(event.log, lines: Self.expandedTail) }

        switch event.outcome {
        case .running: return LogTail.last(event.log, lines: runningTail)
        case .failed: return LogTail.last(event.log, lines: failedTail)
        case .succeeded, .skipped: return ""
        }
    }

    @ViewBuilder
    private func tailText(_ tail: String) -> some View {
        if event.isRunning, !isExpanded {
            let lines = SetupTailLine.lines(of: tail, endingAt: event.log)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(lines) { line in
                    Text(line.text)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(height: lineHeight)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))
                }
            }
            .frame(height: lineHeight * CGFloat(runningTail), alignment: .top)
            .clipped()
            .animation(reduceMotion ? nil : Self.settle, value: lines)
        } else {
            Text(marked(tail))
        }
    }

    private func marked(_ tail: String) -> AttributedString {
        guard event.isFailure, !event.failureSummary.isEmpty else { return AttributedString(tail) }

        var output = AttributedString()
        for line in SetupLogLine.lines(of: tail, failing: event.failureSummary) {
            if line.id > 0 { output += AttributedString("\n") }
            var run = AttributedString(line.text)
            if line.isFailure { run.foregroundColor = Palette.negative }
            output += run
        }
        return output
    }

    private var lineHeight: CGFloat { SetupLineHeight.height(fontScale: fontScale) }

    private static let settle: Animation = Motion.hover

    private func logBlock(_ tail: String) -> some View {
        VStack(alignment: .leading, spacing: TranscriptLayout.tight) {
            tailText(tail)
                .font(Typo.code)
                .foregroundStyle(Palette.textSecondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, TranscriptLayout.block)
                .padding(.vertical, TranscriptLayout.tight)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(Palette.border)
                        .frame(width: TranscriptLayout.rule)
                }

            if showsExpandLink || showsRunSetupAgain || showsStopSetup {
                HStack(spacing: Metrics.gutter) {
                    if showsExpandLink {
                        Button(isExpanded ? "Show less" : "Show more of the log") { isExpanded.toggle() }
                            .linkButton()
                            .font(Typo.caption)
                            .help(isExpanded ? "Folds the log back to its last lines" : "Unfolds the log in this row")
                            .accessibilityHidden(true)
                    }

                    if showsRunSetupAgain, let model {
                        Button("Run setup again") { SetupRunAlert.shared.ask(model) }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .font(Typo.caption)
                            .help("Asks, then runs this repository's setup script in this workspace again")
                    }

                    if showsStopSetup, let model {
                        Button("Stop setup") { model.stopSetup() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .font(Typo.caption)
                            .help("Stops the setup script. Anything waiting for it goes to the agent")
                    }
                }
                .padding(.leading, TranscriptLayout.block)
            }
        }
        .padding(.leading, TranscriptLayout.detailIndent)
        .padding(.trailing, TranscriptLayout.inset)
        .padding(.bottom, TranscriptLayout.block)
    }

    private var showsExpandLink: Bool {
        event.kind == .setup && canExpand && (isExpanded || hasMoreToShow)
    }

    private var showsRunSetupAgain: Bool {
        event.kind == .setup && event.outcome == .failed && model?.canRunSetup == true
    }

    private var showsStopSetup: Bool {
        event.kind == .setup && event.isRunning && model?.isRunningSetup == true
    }

    private var hasMoreToShow: Bool {
        event.logLines > (event.isFailure ? failedTail : tailCap)
    }
}
