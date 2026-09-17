import SwiftUI
import Core

struct ToolRowHeader: View {
    var presentation: ToolPresentation
    var home: TranscriptHome
    var isError: Bool
    var refusal: ToolRefusal?
    var refusalReason: String = ""
    var durationMS: Int?
    var subagentActions: Int?
    var runUnavailable = false
    var onOpenRun: (() -> Void)?
    var onToggle: (() -> Void)?
    var isExpanded: Bool
    var isHovered: Bool
    var showsDisclosure = true

    @Environment(AppModel.self) private var app

    @Environment(\.transcriptHoverHost) private var hoverHost

    @State private var titleIsCut = false
    @State private var detailIsCut = false
    @State private var frameInWindow: CGRect = .zero
    @State private var hoverTask: Task<Void, Never>?
    @State private var published: TranscriptHoverCard?

    private static var hoverDelay: Duration { Motion.hoverCardDelay }

    private var showsDetail: Bool {
        !isExpanded
            && !presentation.detail.isEmpty
            && !presentation.chips.contains { $0.text == presentation.detail }
    }

    private var detailText: Text {
        let lead = presentation.detailLead
        guard !lead.text.isEmpty else { return Text(presentation.detail) }
        let tinted = Text(lead.text).foregroundStyle(lead.tint.colour)
        return Text("\(tinted)\(lead.joiner)\(presentation.detail)")
    }

    private var detailFont: ScaledFont {
        presentation.detailIsCode ? Typo.codeSmall : Typo.label
    }

    private var outcome: (text: String, tint: Color, help: String)? {
        if let refusal {
            var sentence = refusalReason.isEmpty ? refusal.summary : refusalReason
            if let last = sentence.last, !".!?:".contains(last) { sentence += "." }
            return (
                refusal.label,
                Palette.warning,
                [sentence, refusal.remedy].compactMap { $0 }.joined(separator: " ")
            )
        }
        if isError {
            return ("error", Palette.negative, "The tool reported an error. Open the row for what it said.")
        }
        return nil
    }

    var body: some View {
        let outcome = outcome

        return HStack(spacing: TranscriptLayout.glyphGap) {
            if let onOpenRun {
                Button(action: onOpenRun) {
                    HStack(spacing: TranscriptLayout.glyphGap) {
                        summary(outcome: outcome)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(SubagentRunLink.openHelp)
                .accessibilityHint(SubagentRunLink.openHelp)
                .onKeyPress(keys: [.return]) { _ in
                    onOpenRun()
                    return .handled
                }
            } else {
                summary(outcome: outcome)
            }

            Spacer(minLength: TranscriptLayout.tight)

            if let outcome {
                Text(outcome.text)
                    .font(Typo.captionEmphasis)
                    .foregroundStyle(outcome.tint)
                    .fixedSize()
                    .help(outcome.help)
                    .accessibilityLabel(outcome.help)
            }

            if let durationMS, durationMS > 0 {
                Text(TurnDuration.short(durationMS))
                    .font(Typo.micro)
                    .foregroundStyle(Palette.textTertiary)
                    .monospacedDigit()
                    .fixedSize()
            }

            if let onToggle, onOpenRun != nil {
                let title = isExpanded ? "Hide the brief and result" : "Show the brief and result"
                Button(action: onToggle) {
                    TranscriptDisclosure(isExpanded: isExpanded, isVisible: isHovered)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(title)
                .accessibilityLabel(title)
            }
            if onToggle == nil || onOpenRun == nil, showsDisclosure {
                TranscriptDisclosure(isExpanded: isExpanded, isVisible: isHovered)
            }
        }
        .transcriptRowFrame()
        .background { frameProbe }
        .onChange(of: showsCard) { _, wants in
            hoverTask?.cancel()
            guard wants else {
                withdraw()
                return
            }
            let wanted = card
            hoverTask = Task {
                try? await Task.sleep(for: Self.hoverDelay)
                guard !Task.isCancelled, frameInWindow != .zero else { return }
                published = wanted
                hoverHost?.request = TranscriptHoverRequest(card: wanted, frame: frameInWindow)
            }
        }
        .onDisappear {
            hoverTask?.cancel()
            withdraw()
        }
    }

    @ViewBuilder
    private func summary(outcome: (text: String, tint: Color, help: String)?) -> some View {
        TranscriptGlyph(
            symbol: presentation.glyph,
            tint: outcome?.tint ?? presentation.tint.colour
        )

        Text(presentation.label)
            .font(Typo.label)
            .foregroundStyle(Palette.textSecondary)
            .lineLimit(1)
            .truncationMode(.tail)
            .transcriptLabelColumn(presentation.label, font: Typo.label)
            .reportsTruncation(
                of: presentation.label,
                font: Typo.label,
                isActive: wantsMeasuring,
                into: $titleIsCut
            )

        if showsDetail {
            detailText
                .font(detailFont)
                .foregroundStyle(Palette.textTertiary)
                .lineLimit(1)
                .truncationMode(.tail)
                .layoutPriority(1)
                .reportsTruncation(
                    of: presentation.detailLine,
                    font: detailFont,
                    isActive: wantsMeasuring,
                    into: $detailIsCut
                )
        }

        if let subagentActions {
            meta(Counted.of(subagentActions, "action"))
        }
        if subagentActions == nil, runUnavailable {
            meta(SubagentRunLink.unavailableLabel)
                .help(SubagentRunLink.unavailableHelp)
        }

        ForEach(presentation.chips.indices, id: \.self) { index in
            switch presentation.chips[index] {
            case .code(let text):
                Chip(text: text, monospaced: true)
            case .file(let path):
                fileChip(path)
            }
        }
    }

    private func meta(_ text: String) -> some View {
        Text(showsDetail ? "· \(text)" : text)
            .font(Typo.label)
            .foregroundStyle(Palette.textTertiary)
            .monospacedDigit()
            .lineLimit(1)
            .fixedSize()
    }

    private var wantsMeasuring: Bool {
        hoverHost != nil && isHovered && !isExpanded
    }

    private var showsCard: Bool {
        wantsMeasuring && (titleIsCut || detailIsCut)
    }

    private var card: TranscriptHoverCard {
        .row(
            title: presentation.label,
            detail: showsDetail ? presentation.detailLine : "",
            isCode: presentation.detailIsCode
        )
    }

    private func withdraw() {
        defer { published = nil }
        guard let published, hoverHost?.request?.card == published else { return }
        hoverHost?.request = nil
    }

    @ViewBuilder
    private var frameProbe: some View {
        if wantsMeasuring {
            Color.clear
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: {
                    frameInWindow = $0
                }
        }
    }

    private func fileChip(_ path: String) -> some View {
        let target = FileChipTarget.resolve(path, in: home.worktree)
        let attachment = PromptAttachment.sent(path: target.path)
        let worktree = target.worktree
        let onOpen: (@MainActor () -> Void)?
        let onOpenInNewTab: (@MainActor () -> Void)?
        if let opens = target.opens {
            onOpen = { open(opens) }
            onOpenInNewTab = {
                openInNewTab(opens, at: (worktree as NSString).appendingPathComponent(opens))
            }
        } else {
            onOpen = nil
            onOpenInNewTab = nil
        }

        return AttachmentChip(
            attachment: attachment,
            worktree: worktree,
            onOpen: onOpen,
            onOpenInNewTab: onOpenInNewTab,
            onPreview: { frame in
                let file = TranscriptHoverCard.file(attachment: attachment, worktree: worktree)
                guard let frame else {
                    if hoverHost?.request?.card == file { hoverHost?.request = nil }
                    return
                }
                hoverHost?.request = TranscriptHoverRequest(card: file, frame: frame)
            },
            verifiesOnDisk: false
        )
        .fixedSize()
    }

    private func openInNewTab(_ path: String, at absolute: String) {
        guard let id = home.workspaceID, let model = app.existingModel(for: id) else { return }
        guard FileManager.default.fileExists(atPath: absolute) else { return }
        FileReview.openInNewTab(path: path, in: model)
    }

    private func open(_ path: String) {
        guard let id = home.workspaceID, let model = app.existingModel(for: id) else { return }
        FileReview.open(path: path, in: model)
    }
}
