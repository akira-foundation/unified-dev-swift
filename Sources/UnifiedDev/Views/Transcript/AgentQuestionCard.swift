import Observation
import SwiftUI
import Core

struct AgentQuestionCard: View {
    var ask: PermissionAsk
    var decision: String?
    var answers: [String: String] = [:]
    var isExpanded = false
    var onToggle: () -> Void = {}
    var onAnswer: (PermissionDecision) -> Void = { _ in }

    private var box: AgentQuestionDraftBox { AgentQuestionDraftStore.box(for: ask) }

    @State private var openedOther: Set<String> = []
    @State private var isHovered = false
    @FocusState private var otherFocus: String?

    private var questions: [AgentQuestion] { AgentQuestionCache.questions(in: ask) }

    private var isSettled: Bool { decision != nil }

    private var isOpen: Bool {
        AgentQuestionDisclosure.isOpen(isSettled: isSettled, wasReopened: isExpanded)
    }

    private var isLive: Bool { !isSettled }

    private var digests: [AgentQuestionDigest] {
        AgentQuestionDigest.of(questions, answers: recorded)
    }

    private var recorded: [String: String] {
        answers.isEmpty ? box.draft.answers(to: questions) : answers
    }

    var body: some View {
        content
            .padding(TranscriptLayout.cardInset)
        .background(
            RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous)
                .fill(isLive ? Palette.questionWash : Palette.questionWashSettled)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous)
                .strokeBorder(
                    isLive ? Palette.questionBorder : Palette.border,
                    lineWidth: Metrics.outline
                )
        )
        .padding(.vertical, TranscriptLayout.tight)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(isLive ? "The agent is asking a question" : "Question, answered")
        .onHover { isHovered = $0 }
        .task { applyCaptureStates() }
    }

    @ViewBuilder
    private var content: some View {
        if isOpen {
            openCard
        } else {
            ExpandableRowHeader(isExpanded: false, onToggle: onToggle) {
                AgentQuestionClosedCard(
                    digests: digests, settledText: settledText, isHovered: isHovered
                )
                .contentShape(Rectangle())
            }
            .help(AgentQuestionDisclosure.reopenTitle(isOpen: false))
        }
    }

    private var openCard: some View {
        VStack(alignment: .leading, spacing: TranscriptLayout.cardInset) {
            if isSettled {
                ExpandableRowHeader(isExpanded: true, onToggle: onToggle) {
                    header.contentShape(Rectangle())
                }
                .help(AgentQuestionDisclosure.reopenTitle(isOpen: true))
            } else {
                header
            }

            ForEach(questions) { question in
                questionBlock(question)
            }

            if isSettled {
                settledLine
            } else {
                actions
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: TranscriptLayout.glyphGap) {
            Image(systemName: "questionmark.bubble.fill")
                .font(Typo.caption)
                .imageScale(.small)
                .foregroundStyle(isLive ? Palette.accent : Palette.textTertiary)
                .accessibilityHidden(true)

            Text(headerTitle)
                .font(Typo.labelEmphasis)
                .foregroundStyle(Palette.textPrimary)

            Spacer(minLength: 0)

            if isSettled {
                TranscriptDisclosure(isExpanded: true, isVisible: isHovered)
            }
        }
    }

    private var headerTitle: String {
        if questions.count > 1 {
            return isLive
                ? "The agent has \(questions.count) questions"
                : "The agent asked \(questions.count) questions"
        }
        return isLive ? "The agent has a question" : "The agent asked a question"
    }

    private func questionBlock(_ question: AgentQuestion) -> some View {
        VStack(alignment: .leading, spacing: Metrics.spacingWide) {
            VStack(alignment: .leading, spacing: Metrics.spacingSmall) {
                if !question.header.isEmpty {
                    Text(question.header.uppercased())
                        .font(Typo.micro)
                        .tracking(Typo.microTracking)
                        .foregroundStyle(isLive ? Palette.accent : Palette.textTertiary)
                }

                Text(question.question)
                    .font(Typo.bodyEmphasis)
                    .foregroundStyle(Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)

                if question.multiSelect, isLive {
                    Text("Choose as many as apply.")
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textTertiary)
                }
            }

            VStack(alignment: .leading, spacing: Metrics.spacingTight) {
                ForEach(question.options) { option in
                    optionRow(question, option)
                }

                if question.allowsOther { otherRow(question) }
            }
        }
    }

    private func optionRow(_ question: AgentQuestion, _ option: AgentQuestion.Option) -> some View {
        let isChosen = chosen(on: question).contains(option.label)

        return VStack(alignment: .leading, spacing: Metrics.spacingTight) {
            Button {
                toggle(question, option.label)
            } label: {
                rowLabel(
                    mark: markName(isChosen: isChosen, multiSelect: question.multiSelect),
                    isChosen: isChosen,
                    title: option.label,
                    detail: option.description
                )
            }
            .buttonStyle(
                QuestionOptionStyle(
                    isChosen: isChosen,
                    isLive: isLive,
                    forcesHover: forcesHover(question, option)
                )
            )
            .disabled(!isLive)
            .accessibilityAddTraits(isChosen ? [.isSelected] : [])

            if let preview = option.preview, isChosen {
                DetailCodeBlock(text: preview)
                    .padding(.leading, TranscriptLayout.optionTextIndent)
                    .padding(.trailing, Metrics.spacingWide)
                    .padding(.bottom, Metrics.spacingSmall)
            }
        }
    }

    private func rowLabel(mark: String, isChosen: Bool, title: String, detail: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: TranscriptLayout.glyphGap) {
            markView(mark, isChosen: isChosen)

            VStack(alignment: .leading, spacing: Metrics.spacingTight) {
                Text(title)
                    .font(Typo.labelEmphasis)
                    .foregroundStyle(isLive ? Palette.textPrimary : Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if !detail.isEmpty {
                    Text(detail)
                        .font(Typo.caption)
                        .foregroundStyle(isLive ? Palette.textSecondary : Palette.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func markView(_ name: String, isChosen: Bool) -> some View {
        Image(systemName: name)
            .font(Typo.body)
            .foregroundStyle(markColour(isChosen: isChosen))
            .frame(width: TranscriptLayout.glyphWidth)
            .accessibilityHidden(true)
    }

    private func markColour(isChosen: Bool) -> Color {
        if isChosen { return Palette.accent }
        return isLive ? Palette.textSecondary : Palette.textTertiary
    }

    @ViewBuilder
    private func otherRow(_ question: AgentQuestion) -> some View {
        let isWriting = question.options.isEmpty || box.draft.isWritingOther.contains(question.id)
        if isWriting {
            HStack(alignment: .firstTextBaseline, spacing: TranscriptLayout.glyphGap) {
                markView(
                    markName(isChosen: true, multiSelect: question.multiSelect),
                    isChosen: true
                )

                let answer = Binding(
                        get: { box.draft.other[question.id] ?? "" },
                        set: { box.draft.other[question.id] = $0 }
                )
                if !isLive, !question.isSecret, !answer.wrappedValue.isEmpty {
                    Text(answer.wrappedValue)
                        .font(Typo.label)
                        .foregroundStyle(Palette.textPrimary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Group {
                        if question.isSecret {
                            SecureField("Your answer", text: answer)
                        } else {
                            TextField("Your answer", text: answer, axis: .vertical)
                        }
                    }
                    .textFieldStyle(.roundedBorder)
                    .font(Typo.label)
                    .lineLimit(1...4)
                    .focused($otherFocus, equals: question.id)
                    .disabled(!isLive)
                    .task {
                        guard openedOther.contains(question.id) else { return }
                        otherFocus = question.id
                    }
                    .onKeyPress(keys: [.return]) { press in
                        guard press.modifiers.isEmpty, isComplete else { return .ignored }
                        send()
                        return .handled
                    }
                }
            }
            .padding(.vertical, Metrics.spacing)
            .padding(.horizontal, Metrics.spacingWide)
            .focusedValue(\.isTypingProse, otherFocus != nil)
        }
        if !isWriting, isLive {
            Button {
                openedOther.insert(question.id)
                box.draft.writeOther(on: question)
            } label: {
                rowLabel(
                    mark: markName(isChosen: false, multiSelect: question.multiSelect),
                    isChosen: false,
                    title: AgentQuestionnaire.otherLabel,
                    detail: "Answer in your own words."
                )
            }
            .buttonStyle(QuestionOptionStyle(isChosen: false, isLive: true))
        }
    }

    private var actions: some View {
        HStack(spacing: TranscriptLayout.tight) {
            Button("Send answer") { send() }
                .buttonStyle(.borderedProminent)
                .tint(Palette.controlAccent)
                .keyboardShortcut(.defaultAction)
                .disabled(!isComplete)

            Spacer(minLength: 0)

            Button("Let the agent decide") {
                onAnswer(.deny(message: Self.skipMessage, endsTurn: false))
            }
            .buttonStyle(.bordered)
        }
        .controlSize(.small)
    }

    private var settledLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: TranscriptLayout.glyphGap) {
            if decision == PermissionDecision.answeredName {
                Image(systemName: "checkmark.circle.fill")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.accent)
                    .accessibilityHidden(true)
            }

            Text(settledText)
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var settledText: String {
        let decision = decision ?? ""
        let unanswered = PermissionAskOutcome.summary(decision)
        if !unanswered.isEmpty { return unanswered }
        return decision == PermissionDecision.answeredName
            ? "Answered."
            : "The agent was asked to decide for itself."
    }

    private static let skipMessage =
        "No answer was given. Choose whichever option you judge best, say which you chose and why, "
            + "and carry on without asking again."

    private var isComplete: Bool {
        box.draft.isComplete(questions)
    }

    private func send() {
        guard isComplete else { return }
        let drafted = box.draft.answers(to: questions)
        onAnswer(.answer(input: AgentQuestionnaire.answered(ask.input, answers: drafted)))
    }

    private func toggle(_ question: AgentQuestion, _ label: String) {
        box.draft.toggle(label, on: question)
    }

    private func chosen(on question: AgentQuestion) -> Set<String> {
        guard isSettled else { return box.draft.chosen[question.id] ?? [] }
        if let ticked = box.draft.chosen[question.id], !ticked.isEmpty { return ticked }
        return digests.first { $0.id == question.id }?.chosen ?? []
    }

    private func markName(isChosen: Bool, multiSelect: Bool) -> String {
        if multiSelect {
            return isChosen ? "checkmark.square.fill" : "square"
        }
        return isChosen ? "largecircle.fill.circle" : "circle"
    }

    #if DEBUG
    private static let forcesStates = CommandLine.arguments.contains("--question-states")
    #endif

    private func applyCaptureStates() {
        #if DEBUG
        guard Self.forcesStates, isLive else { return }
        for question in questions {
            if let first = question.options.first {
                box.draft.chosen[question.id] = [first.label]
            }
        }
        #endif
    }

    private func forcesHover(_ question: AgentQuestion, _ option: AgentQuestion.Option) -> Bool {
        #if DEBUG
        return Self.forcesStates && isLive && question.options.firstIndex(of: option) == 1
        #else
        return false
        #endif
    }
}
