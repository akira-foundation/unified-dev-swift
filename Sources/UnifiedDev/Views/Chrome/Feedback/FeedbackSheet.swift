import AppKit
import SwiftUI
import Core

struct FeedbackSheet: View {
    @Environment(AppModel.self) private var app

    @Bindable private var presenter = FeedbackPresenter.shared

    @State private var caret = 0
    @State private var isFocused = false
    @State private var contentHeight = ComposerTextEditor.lineHeight
    @State private var phase: FeedbackPhase = .idle
    @State private var isShowingLogs = false
    @State private var attachmentProblem: String?
    @State private var facts: Task<Feedback.Environment, Never>?
    @State private var logsRead: Task<Void, Never>?
    @State private var hasTriedToSend = false
    @FocusState private var problemField: Feedback.SheetField?

    private static let minimumEditorLines: CGFloat = 5
    private static let maximumEditorLines: CGFloat = 14

    private static let width: CGFloat = 620

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.gutter) {
            FeedbackHeader(title: Feedback.Copy.reportTitle, blurb: Feedback.Copy.reportBlurb)

            editor

            if !presenter.images.isEmpty { images }

            if let attachmentProblem {
                Label(attachmentProblem, systemImage: "exclamationmark.triangle.fill")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }

            logsRow

            FeedbackEmailField(
                label: Feedback.Copy.reportEmail,
                email: $presenter.email,
                problem: problems.email,
                problemField: $problemField
            )

            FeedbackEnvironmentNote()

            footer
        }
        .padding(Metrics.pane)
        .frame(width: Self.width)
        .background(Palette.surface)
        .task {
            facts = Task { await FeedbackEnvironment.current(app: app) }
            isFocused = true
            if presenter.includesLogs { readLogs() }
        }
        .onDisappear {
            facts?.cancel()
            phase = .idle
            hasTriedToSend = false
        }
        .task {
            #if DEBUG
            if CommandLine.arguments.contains("--feedback-problems") { hasTriedToSend = true }
            guard CommandLine.arguments.contains("--feedback-logs") else { return }
            showLogs()
            #endif
        }
        .sheet(isPresented: $isShowingLogs) {
            FeedbackLogSheet(text: presenter.logs) { isShowingLogs = false }
        }
    }

    private var editor: some View {
        ComposerEditor(
            text: $presenter.message,
            caret: $caret,
            isFocused: $isFocused,
            height: editorHeight,
            onContentHeightChange: { contentHeight = $0 },
            onKey: handle(key:),
            onAttach: attach(sources:replacing:),
            placeholder: Feedback.Copy.reportPlaceholder
        )
        .composerBox(isFocused: $isFocused)
    }

    private var editorHeight: CGFloat {
        let line = ComposerTextEditor.lineHeight
        return min(max(contentHeight, line * Self.minimumEditorLines), line * Self.maximumEditorLines)
    }

    private var images: some View {
        ChipFlow(spacing: Metrics.spacing, lineSpacing: Metrics.spacing) {
            ForEach(presenter.images) { image in
                FeedbackImageChip(image: image) { remove(image) }
            }
        }
    }

    private var logsRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: Metrics.spacingWide) {
            Toggle(Feedback.Copy.logsToggle, isOn: $presenter.includesLogs)
                .toggleStyle(.checkbox)
                .tint(Palette.controlAccent)
                .font(Typo.caption)

            Button(Feedback.Copy.logsView) { showLogs() }
                .linkButton()
                .font(Typo.caption)
                .help("Read exactly what would be sent")

            Spacer(minLength: Metrics.gutter)

            if let remaining = Feedback.remainingMessage(
                count: presenter.message.count, limit: Feedback.maxMessageCharacters
            ) {
                Text(remaining)
                    .font(Typo.micro)
                    .foregroundStyle(
                        presenter.message.count > Feedback.maxMessageCharacters
                            ? Palette.warning
                            : Palette.textTertiary
                    )
                    .monospacedDigit()
            }
        }
        .onChange(of: presenter.includesLogs) { _, isOn in
            guard isOn else { return }
            readLogs()
        }
    }

    private var footer: some View {
        HStack(spacing: Metrics.gutter) {
            Button(Feedback.Copy.attachImages, systemImage: "photo.on.rectangle") { pickImages() }
                .disabled(presenter.images.count >= Feedback.maxImages || phase.isSending)
                .help("Up to \(Feedback.maxImages) pictures. You can also paste or drop one on the box above.")

            Spacer(minLength: Metrics.gutter)

            FeedbackStatus(phase: phase)

            Button("Cancel", role: .cancel) { presenter.close() }
                .keyboardShortcut(.cancelAction)
                .disabled(phase.isSending)

            FeedbackSendButton(
                title: Feedback.Copy.reportSend,
                isEnabled: canSend,
                isSending: phase.isSending,
                action: send
            )
        }
    }

    private func handle(key: ComposerKey) -> Bool {
        switch key {
        case .commandReturn:
            send()
            return true
        case .escape:
            guard !phase.isSending else { return true }
            presenter.close()
            return true
        case .up, .down, .returnKey, .tab:
            return false
        }
    }

    private func readLogs() {
        logsRead?.cancel()

        let redaction = AppLogExcerpt.Redaction.of(
            projects: app.repos.map(\.name),
            workspaces: app.workspaces.map(\.name),
            branches: app.workspaces.map(\.branch),
            user: NSUserName(),
            host: ProcessInfo.processInfo.hostName
        )

        logsRead = Task {
            let excerpt = await Task.detached(priority: .userInitiated) {
                AppLogExcerpt.excerpt(AppLogReader.recent(), redaction: redaction)
            }.value
            guard !Task.isCancelled else { return }
            presenter.logs = excerpt
        }
    }

    private func showLogs() {
        readLogs()
        Task {
            await logsRead?.value
            isShowingLogs = true
        }
    }

    private func attach(sources: [AttachmentSource], replacing range: NSRange) -> Bool {
        guard !sources.isEmpty else { return false }
        add(sources)
        return true
    }

    private func pickImages() {
        Task {
            let panel = NSOpenPanel()
            panel.canChooseFiles = true
            panel.canChooseDirectories = false
            panel.allowsMultipleSelection = true
            panel.allowedContentTypes = [.image]
            panel.prompt = "Attach"

            guard await panel.present() == .OK else { return }
            add(panel.urls.map { .file($0) })
        }
    }

    private func add(_ sources: [AttachmentSource]) {
        let existing = presenter.images
        Task {
            do {
                let read = try await Task.detached(priority: .userInitiated) {
                    try FeedbackImages.read(sources, existing: existing)
                }.value
                presenter.images += read
                attachmentProblem = nil
            } catch {
                attachmentProblem = error.localizedDescription
            }
            isFocused = true
        }
    }

    private func remove(_ image: FeedbackImage) {
        presenter.images.removeAll { $0.id == image.id }
        attachmentProblem = nil
    }

    private func gatheredFacts() async -> Feedback.Environment {
        if let facts { return await facts.value }
        return await FeedbackEnvironment.current(app: app)
    }

    private var problems: Feedback.SheetProblems {
        Feedback.sheetProblems(email: presenter.email, afterSendAttempt: hasTriedToSend)
    }

    private var canSend: Bool {
        Feedback.canSend(message: presenter.message) && !phase.isSending
    }

    private func send() {
        guard canSend else { return }

        let problems = Feedback.sheetProblems(email: presenter.email, afterSendAttempt: true)
        guard problems.isEmpty else {
            hasTriedToSend = true
            problemField = problems.firstField
            return
        }

        phase = .sending

        Task {
            let environment = await gatheredFacts()
            if presenter.includesLogs { await logsRead?.value }

            let report = Feedback.Report(
                message: presenter.message,
                email: presenter.email,
                logs: presenter.includesLogs ? presenter.logs : nil,
                images: presenter.images.map(\.wire),
                token: FeedbackEnvironment.token(),
                environment: environment
            )

            let result = await FeedbackClient.send(report)

            guard result.isSent else {
                phase = .failed(Feedback.failureMessage(result.outcome) ?? "That did not send.")
                return
            }

            phase = .sent
            presenter.clearReport()
            presenter.open(.reportSent)
        }
    }
}

private struct FeedbackImageChip: View {
    var image: FeedbackImage
    var onRemove: @MainActor () -> Void

    var body: some View {
        HStack(spacing: Metrics.spacingSmall) {
            Image(systemName: "photo")
                .font(.system(size: Metrics.glyph - 2))
                .foregroundStyle(Palette.textSecondary)

            Text(image.filename)
                .font(Typo.caption)
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)

            Text(ByteCountFormatter.string(fromByteCount: Int64(image.byteCount), countStyle: .file))
                .font(Typo.micro)
                .foregroundStyle(Palette.textTertiary)

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: Metrics.glyph - 4, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Palette.textTertiary)
            .help("Take this image off")
            .accessibilityLabel("Remove \(image.filename)")
        }
        .padding(.horizontal, Metrics.spacing)
        .padding(.vertical, Metrics.spacingSmall)
        .background(Palette.surfaceSunken, in: RoundedRectangle(cornerRadius: Metrics.cornerSmall))
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.cornerSmall)
                .strokeBorder(Palette.border, lineWidth: Metrics.outline)
        )
        .frame(maxWidth: 260, alignment: .leading)
    }
}
