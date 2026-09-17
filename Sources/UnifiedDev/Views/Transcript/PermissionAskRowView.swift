import SwiftUI
import Core

struct PermissionAskRowView: View {
    var ask: PermissionAsk
    var decision: String?
    var note: String
    var projectName: String?
    var onAnswer: (PermissionDecision) -> Void = { _ in }

    @State private var isWritingReason = false
    @State private var reason = ""
    @FocusState private var isReasonFocused: Bool

    @Environment(\.fontScale) private var fontScale
    @Environment(\.chatFont) private var chatFont

    private var codeLeading: CGFloat {
        TranscriptLayout.codeLeading(Typo.codeSmall, scale: fontScale, face: chatFont)
    }

    private var isOpen: Bool { decision == nil }

    private var offer: PermissionScopeOffer {
        PermissionScopeOffer.of(ask: ask, project: projectName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TranscriptLayout.cardInset) {
            header
            command
            if isOpen {
                if isWritingReason {
                    reasonBox
                } else if ask.isPlanApproval {
                    planActions
                } else {
                    actions
                }
            } else {
                outcome
            }
        }
        .padding(TranscriptLayout.cardInset)
        .background(
            RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous)
                .fill(isOpen ? Palette.cautionWash : Palette.cautionWashSettled)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous)
                .strokeBorder(
                    isOpen ? Palette.cautionBorder : Palette.border,
                    lineWidth: Metrics.outline
                )
        )
        .padding(.vertical, TranscriptLayout.tight)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(isOpen ? "The agent is asking permission" : "Permission question, answered")
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: TranscriptLayout.glyphGap) {
            Image(systemName: "hand.raised.fill")
                .font(Typo.caption)
                .imageScale(.small)
                .foregroundStyle(isOpen ? Palette.warning : Palette.textTertiary)
                .accessibilityHidden(true)

            Text(title)
                .font(Typo.labelEmphasis)
                .foregroundStyle(Palette.textPrimary)

            Spacer(minLength: TranscriptLayout.glyphGap)

            if !ask.reason.isEmpty {
                Text(ask.reason)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }

    @ViewBuilder
    private var command: some View {
        if ask.isPlanApproval, isOpen, let plan = ask.input["plan"]?.stringValue, !plan.isEmpty {
            Text(plan)
                .font(Typo.label)
                .foregroundStyle(Palette.textPrimary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        } else if !ask.subject.isEmpty {
            HStack(alignment: .top, spacing: TranscriptLayout.glyphGap) {
                Text(ask.subject)
                    .font(ask.subjectIsCode ? Typo.codeSmall : Typo.label)
                    .foregroundStyle(Palette.textPrimary)
                    .lineSpacing(ask.subjectIsCode ? codeLeading : 0)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)

                CopyButton(
                    text: ask.subject,
                    title: ask.toolName == "Bash" ? "Copy command" : "Copy"
                )
            }
            .padding(.horizontal, Metrics.spacingWide)
            .padding(.vertical, Metrics.spacing)
            .background(
                RoundedRectangle(cornerRadius: Metrics.cornerSmall, style: .continuous)
                    .fill(Palette.surfaceSunken)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.cornerSmall, style: .continuous)
                    .strokeBorder(Palette.border, lineWidth: Metrics.outline)
            )
            .contextMenu {
                Button("Copy") { Clipboard.copy(ask.subject) }
            }
        }
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: Metrics.spacing) {
            HStack(spacing: Metrics.gutter) {
                HStack(spacing: Metrics.spacing) {
                    Button(offer.prominent.buttonLabel) { onAnswer(.allow(scope: offer.prominent)) }
                        .buttonStyle(.borderedProminent)
                        .tint(Palette.controlAccent)
                        .keyboardShortcut(.return, modifiers: offer.widens ? EventModifiers.command : [])

                    ForEach(Array(offer.scopes.dropFirst()), id: \.self) { scope in
                        Button(scope.compactLabel) { onAnswer(.allow(scope: scope)) }
                            .buttonStyle(.bordered)
                    }
                }

                HStack(spacing: Metrics.spacing) {
                    Button("Deny") { onAnswer(.deny(message: "", endsTurn: false)) }
                        .buttonStyle(.bordered)

                    Button("Deny and say why") {
                        isWritingReason = true
                        isReasonFocused = true
                    }
                    .buttonStyle(.borderless)
                    .font(Typo.caption)
                }

                Spacer(minLength: 0)
            }
            .controlSize(.small)

            scopeLine
        }
    }

    private var planActions: some View {
        let mode = PlanApproval.implementationMode(ask.implementationMode ?? .acceptEdits)
        return VStack(alignment: .leading, spacing: Metrics.spacing) {
            Text("Implementation permissions: \(mode.label)")
                .font(Typo.labelEmphasis)
                .foregroundStyle(Palette.textPrimary)
            Text(mode.summary(on: .claudeCode))
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: Metrics.spacing) { planButtons(mode: mode) }
                VStack(alignment: .leading, spacing: Metrics.spacing) { planButtons(mode: mode) }
            }
        }
    }

    @ViewBuilder
    private func planButtons(mode: PermissionMode) -> some View {
        Button("Approve and implement") { onAnswer(.approvePlan(mode: mode)) }
            .buttonStyle(.borderedProminent)
            .tint(Palette.controlAccent)
            .keyboardShortcut(.return, modifiers: .command)
        Menu("Other permissions") {
            ForEach(PlanApproval.modes.filter { $0 != mode }, id: \.self) { alternative in
                Button("Approve with \(alternative.label)") { onAnswer(.approvePlan(mode: alternative)) }
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        Button("Keep planning") {
            onAnswer(.deny(message: PlanApproval.keepPlanningMessage, endsTurn: false))
        }
        .buttonStyle(.bordered)
        Button("Give feedback…") { isWritingReason = true }
            .buttonStyle(.borderless)
    }

    private var scopeLine: some View {
        Text(offer.explanation)
            .font(Typo.caption)
            .foregroundStyle(Palette.textTertiary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var reasonBox: some View {
        VStack(alignment: .leading, spacing: Metrics.spacing) {
            TextField("Why not? The agent reads this.", text: $reason, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .font(Typo.label)
                .lineLimit(1...4)
                .focused($isReasonFocused)
                .onSubmit { onAnswer(.deny(message: reason, endsTurn: false)) }

            HStack(spacing: Metrics.gutter) {
                HStack(spacing: Metrics.spacing) {
                    Button("Deny") { onAnswer(.deny(message: reason, endsTurn: false)) }
                        .buttonStyle(.borderedProminent)
                        .tint(Palette.controlAccent)
                        .keyboardShortcut(.return, modifiers: .command)

                    Button("Deny and stop the turn") {
                        onAnswer(.deny(message: reason, endsTurn: true))
                    }
                    .buttonStyle(.bordered)
                }

                Button("Back") { isWritingReason = false }
                    .buttonStyle(.borderless)
                    .font(Typo.caption)
                    .keyboardShortcut(.cancelAction)

                Spacer(minLength: 0)
            }
            .controlSize(.small)
        }
    }

    @ViewBuilder
    private var outcome: some View {
        let decision = decision ?? ""
        VStack(alignment: .leading, spacing: Metrics.spacingSmall) {
            Text(outcomeText(decision))
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            let advice = PermissionAskOutcome.advice(decision)
            if !advice.isEmpty {
                Text(advice)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var title: String {
        if ask.isPlanApproval { return isOpen ? "Ready to implement the plan" : "Plan review" }
        let verb = ask.toolName == "Bash" ? "run a command" : "use \(ask.label)"
        return isOpen ? "The agent is asking to \(verb)" : "The agent asked to \(verb)"
    }

    private func outcomeText(_ decision: String) -> String {
        if let mode = PlanApproval.approvedMode(storedDecision: decision) {
            return "Plan approved. Implementation permissions: \(mode.label)."
        }
        if !note.isEmpty { return note }

        let unanswered = PermissionAskOutcome.summary(decision)
        if !unanswered.isEmpty { return unanswered }

        switch decision {
        case PermissionAskOutcome.auto:
            return "Allowed by \(ask.ruleText), which you approved for \(projectName ?? "this project")."
        case "allow-project":
            return "Always allowed. \(ask.ruleText) is granted for \(projectName ?? "this project")."
        case "allow-session": return "Allowed for this session."
        case "allow-once": return "Allowed once."
        case "deny-stop": return "Denied, and the turn was stopped."
        case "deny": return "Denied."
        default: return "Answered."
        }
    }
}
