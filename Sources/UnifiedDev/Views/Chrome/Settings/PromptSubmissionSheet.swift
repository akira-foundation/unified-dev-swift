import SwiftUI
import Core

struct PromptSubmissionSheet: View {
    @Environment(AppModel.self) private var app

    @Bindable private var presenter = FeedbackPresenter.shared

    @State private var caret = 0
    @State private var isFocused = false
    @State private var contentHeight = ComposerTextEditor.lineHeight
    @State private var phase: FeedbackPhase = .idle
    @State private var facts: Task<Feedback.Environment, Never>?
    @State private var hasTriedToSend = false
    @FocusState private var problemField: Feedback.SheetField?

    private static let minimumEditorLines: CGFloat = 6
    private static let maximumEditorLines: CGFloat = 14
    private static let width: CGFloat = 620

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.gutter) {
            FeedbackHeader(title: Feedback.Copy.promptTitle, blurb: Feedback.Copy.promptBlurb)

            editor

            nameField

            FeedbackEmailField(
                label: Feedback.Copy.promptEmail,
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
        }
        .onDisappear {
            facts?.cancel()
            phase = .idle
            hasTriedToSend = false
        }
        .task {
            #if DEBUG
            if CommandLine.arguments.contains("--prompt-problems") { hasTriedToSend = true }
            #endif
        }
    }

    private var editor: some View {
        ComposerEditor(
            text: $presenter.prompt,
            caret: $caret,
            isFocused: $isFocused,
            height: editorHeight,
            onContentHeightChange: { contentHeight = $0 },
            onKey: handle(key:),
            onAttach: { _, _ in true },
            placeholder: Feedback.Copy.promptPlaceholder
        )
        .composerBox(isFocused: $isFocused)
    }

    private var editorHeight: CGFloat {
        let line = ComposerTextEditor.lineHeight
        return min(max(contentHeight, line * Self.minimumEditorLines), line * Self.maximumEditorLines)
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingSmall) {
            Text(Feedback.Copy.promptName)
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            TextField(Feedback.Copy.promptNamePlaceholder, text: $presenter.name)
                .textFieldStyle(.roundedBorder)
                .font(Typo.body)
                .focused($problemField, equals: .name)

            FeedbackFieldProblem(message: Feedback.nameProblem, isShown: problems.name != nil)
        }
    }

    private var problems: Feedback.SheetProblems {
        Feedback.sheetProblems(
            name: presenter.name, email: presenter.email, afterSendAttempt: hasTriedToSend
        )
    }

    private var footer: some View {
        HStack(spacing: Metrics.gutter) {
            if let remaining = Feedback.remainingMessage(
                count: presenter.prompt.count, limit: Feedback.maxPromptCharacters
            ) {
                Text(remaining)
                    .font(Typo.micro)
                    .foregroundStyle(
                        presenter.prompt.count > Feedback.maxPromptCharacters
                            ? Palette.warning
                            : Palette.textTertiary
                    )
                    .monospacedDigit()
            }

            Spacer(minLength: Metrics.gutter)

            FeedbackStatus(phase: phase)

            Button("Cancel", role: .cancel) { presenter.close() }
                .keyboardShortcut(.cancelAction)
                .disabled(phase.isSending)

            FeedbackSendButton(
                title: Feedback.Copy.promptSend,
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

    private func gatheredFacts() async -> Feedback.Environment {
        if let facts { return await facts.value }
        return await FeedbackEnvironment.current(app: app)
    }

    private var canSend: Bool {
        Feedback.canSend(message: presenter.prompt) && !phase.isSending
    }

    private func send() {
        guard canSend else { return }

        let problems = Feedback.sheetProblems(
            name: presenter.name, email: presenter.email, afterSendAttempt: true
        )
        guard problems.isEmpty else {
            hasTriedToSend = true
            problemField = problems.firstField
            return
        }

        phase = .sending

        Task {
            let environment = await gatheredFacts()

            let submission = Feedback.PromptSubmission(
                prompt: presenter.prompt,
                name: presenter.name,
                email: presenter.email,
                token: FeedbackEnvironment.token(),
                environment: environment
            )

            let result = await FeedbackClient.send(submission)

            guard result.isSent else {
                phase = .failed(Feedback.failureMessage(result.outcome) ?? "That did not send.")
                return
            }

            phase = .sent
            presenter.clearPrompt()
            presenter.open(.promptSent)
        }
    }
}
