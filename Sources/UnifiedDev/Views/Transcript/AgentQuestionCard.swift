import Observation
import SwiftUI
import Core

struct AgentQuestionCard: View {
    var ask: PermissionAsk
    var decision: String?
    var onAnswer: (PermissionDecision) -> Void = { _ in }

    private var box: AgentQuestionDraftBox { AgentQuestionDraftStore.box(for: ask) }

    @State private var openedOther: Set<String> = []
    @FocusState private var otherFocus: String?

    private var questions: [AgentQuestion] { AgentQuestionCache.questions(in: ask) }

    private var isOpen: Bool { decision == nil }

    var body: some View {
        VStack(alignment: .leading, spacing: TranscriptLayout.cardInset) {
            header

            ForEach(questions) { question in
                questionBlock(question)
            }

            if isOpen {
                actions
            } else {
                settledLine
            }
        }
        .padding(TranscriptLayout.cardInset)
        .background(
            RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous)
                .fill(isOpen ? Palette.questionWash : Palette.questionWashSettled)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous)
                .strokeBorder(
                    isOpen ? Palette.questionBorder : Palette.border,
                    lineWidth: Metrics.outline
                )
        )
        .padding(.vertical, TranscriptLayout.tight)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(isOpen ? "The agent is asking a question" : "Question, answered")
        .task { applyCaptureStates() }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: TranscriptLayout.glyphGap) {
            Image(systemName: "questionmark.bubble.fill")
                .font(Typo.caption)
                .imageScale(.small)
                .foregroundStyle(isOpen ? Palette.accent : Palette.textTertiary)
                .accessibilityHidden(true)

            Text(headerTitle)
                .font(Typo.labelEmphasis)
                .foregroundStyle(Palette.textPrimary)

            Spacer(minLength: 0)
        }
    }

    private var headerTitle: String {
        if questions.count > 1 {
            return isOpen
                ? "The agent has \(questions.count) questions"
                : "The agent asked \(questions.count) questions"
        }
        return isOpen ? "The agent has a question" : "The agent asked a question"
    }

    private func questionBlock(_ question: AgentQuestion) -> some View {
        VStack(alignment: .leading, spacing: Metrics.spacingWide) {
            VStack(alignment: .leading, spacing: Metrics.spacingSmall) {
                if !question.header.isEmpty {
                    Text(question.header.uppercased())
                        .font(Typo.micro)
                        .tracking(Typo.microTracking)
                        .foregroundStyle(isOpen ? Palette.accent : Palette.textTertiary)
                }

                Text(question.question)
                    .font(Typo.bodyEmphasis)
                    .foregroundStyle(Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)

                if question.multiSelect, isOpen {
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
        let isChosen = box.draft.chosen[question.id]?.contains(option.label) ?? false

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
                    isOpen: isOpen,
                    forcesHover: forcesHover(question, option)
                )
            )
            .disabled(!isOpen)
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
                    .foregroundStyle(isOpen ? Palette.textPrimary : Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if !detail.isEmpty {
                    Text(detail)
                        .font(Typo.caption)
                        .foregroundStyle(isOpen ? Palette.textSecondary : Palette.textTertiary)
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
        return isOpen ? Palette.textSecondary : Palette.textTertiary
    }

    @ViewBuilder
    private func otherRow(_ question: AgentQuestion) -> some View {
        if question.options.isEmpty || box.draft.isWritingOther.contains(question.id) {
            HStack(alignment: .firstTextBaseline, spacing: TranscriptLayout.glyphGap) {
                markView(
                    markName(isChosen: true, multiSelect: question.multiSelect),
                    isChosen: true
                )

                let answer = Binding(
                        get: { box.draft.other[question.id] ?? "" },
                        set: { box.draft.other[question.id] = $0 }
                )
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
                .disabled(!isOpen)
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
            .padding(.vertical, Metrics.spacing)
            .padding(.horizontal, Metrics.spacingWide)
            .focusedValue(\.isTypingProse, otherFocus != nil)
        } else if isOpen {
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
            .buttonStyle(QuestionOptionStyle(isChosen: false, isOpen: true))
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
            if decision == "answered" {
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
        return decision == "answered" ? "Answered." : "The agent was asked to decide for itself."
    }

    private static let skipMessage =
        "No answer was given. Choose whichever option you judge best, say which you chose and why, "
            + "and carry on without asking again."

    private var isComplete: Bool {
        box.draft.isComplete(questions)
    }

    private var answers: [String: String] {
        box.draft.answers(to: questions)
    }

    private func send() {
        guard isComplete else { return }
        onAnswer(.answer(input: AgentQuestionnaire.answered(ask.input, answers: answers)))
    }

    private func toggle(_ question: AgentQuestion, _ label: String) {
        box.draft.toggle(label, on: question)
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
        guard Self.forcesStates, isOpen else { return }
        for question in questions {
            if let first = question.options.first {
                box.draft.chosen[question.id] = [first.label]
            }
        }
        #endif
    }

    private func forcesHover(_ question: AgentQuestion, _ option: AgentQuestion.Option) -> Bool {
        #if DEBUG
        return Self.forcesStates && isOpen && question.options.firstIndex(of: option) == 1
        #else
        return false
        #endif
    }
}

private struct QuestionOptionStyle: ButtonStyle {
    var isChosen: Bool
    var isOpen: Bool
    var forcesHover: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        Plate(
            configuration: configuration,
            isChosen: isChosen,
            isOpen: isOpen,
            forcesHover: forcesHover
        )
    }

    private struct Plate: View {
        let configuration: Configuration
        var isChosen: Bool
        var isOpen: Bool

        @State private var isHovered: Bool
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        init(configuration: Configuration, isChosen: Bool, isOpen: Bool, forcesHover: Bool) {
            self.configuration = configuration
            self.isChosen = isChosen
            self.isOpen = isOpen
            _isHovered = State(initialValue: forcesHover)
        }

        var body: some View {
            configuration.label
                .padding(.vertical, Metrics.spacing)
                .padding(.horizontal, Metrics.spacingWide)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous)
                        .fill(fill)
                )
                .contentShape(RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous))
                .animation(reduceMotion ? nil : Motion.hover, value: isHovered)
                .onHover { isHovered = $0 }
        }

        private var fill: Color {
            if isChosen || (isOpen && configuration.isPressed) { return Palette.selected }
            if isOpen, isHovered { return Palette.hover }
            return .clear
        }
    }
}

@MainActor
private enum AgentQuestionCache {
    private static let values: NSCache<NSString, AgentQuestionsBox> = {
        let cache = NSCache<NSString, AgentQuestionsBox>()
        cache.countLimit = 64
        return cache
    }()

    static func questions(in ask: PermissionAsk) -> [AgentQuestion] {
        let key = askKey(ask) as NSString
        if let cached = values.object(forKey: key) { return cached.value }

        let value = AgentQuestionnaire.questions(in: ask.input)
        values.setObject(AgentQuestionsBox(value), forKey: key)
        return value
    }
}

private final class AgentQuestionsBox {
    let value: [AgentQuestion]

    init(_ value: [AgentQuestion]) { self.value = value }
}

private func askKey(_ ask: PermissionAsk) -> String {
    "\(ask.requestID)\u{1}\(ask.toolUseID)"
}

@MainActor
private enum AgentQuestionDraftStore {
    private static let limit = 64

    private static var boxes: [String: AgentQuestionDraftBox] = [:]
    private static var order: [String] = []

    static func box(for ask: PermissionAsk) -> AgentQuestionDraftBox {
        let key = askKey(ask)

        if let box = boxes[key] { return box }

        let box = AgentQuestionDraftBox()
        boxes[key] = box
        order.append(key)

        while order.count > limit {
            boxes.removeValue(forKey: order.removeFirst())
        }

        return box
    }
}

@MainActor
@Observable
private final class AgentQuestionDraftBox {
    var draft = AgentQuestionDraft()
}
