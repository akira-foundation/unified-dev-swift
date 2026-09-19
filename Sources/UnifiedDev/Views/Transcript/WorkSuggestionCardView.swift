import SwiftUI
import Core

struct WorkSuggestionCardView: View {
    var suggestionID: WorkSuggestionID

    @Environment(AppModel.self) private var app

    @State private var suggestion: WorkSuggestion?
    @State private var chatIsSubagent = false
    @State private var showsPrompt = false
    @State private var isPressing = false

    var body: some View {
        Group {
            if let suggestion {
                card(suggestion, in: context(of: suggestion))
                    .padding(.horizontal, TranscriptLayout.inset)
                    .padding(.vertical, TranscriptLayout.block)
            }
        }
        .task(id: app.workSuggestionsRevision) {
            let read = await app.workSuggestion(id: suggestionID)
            let subagent = if let read { await app.workSuggestionContext(for: read).chatIsSubagent } else { false }
            guard !Task.isCancelled else { return }
            if subagent != chatIsSubagent { chatIsSubagent = subagent }
            if read != suggestion { suggestion = read }
        }
    }

    private func context(of suggestion: WorkSuggestion) -> WorkSuggestionCard.Context {
        .of(suggestion, workspaces: app.workspaces, repos: app.repos, chatIsSubagent: chatIsSubagent)
    }

    private func card(_ suggestion: WorkSuggestion, in context: WorkSuggestionCard.Context) -> some View {
        VStack(alignment: .leading, spacing: TranscriptLayout.tight) {
            Label(WorkSuggestionCard.heading, systemImage: WorkSuggestionSidebarMark.symbol)
                .font(Typo.micro)
                .foregroundStyle(Palette.textTertiary)

            Text(suggestion.title)
                .font(Typo.bodyEmphasis)
                .foregroundStyle(Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Text(suggestion.why)
                .font(Typo.body)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if let line = WorkSuggestionCard.targetLine(for: suggestion, in: context) {
                Text(line)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            DisclosureGroup(isExpanded: $showsPrompt) {
                Text(suggestion.prompt)
                    .font(Typo.codeSmall)
                    .foregroundStyle(Palette.textPrimary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } label: {
                Text("Prompt")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
            }

            status(of: suggestion)
            offers(for: suggestion, in: context)
        }
        .padding(Metrics.inset)
        .frame(maxWidth: TranscriptLayout.proseMeasure, alignment: .leading)
        .background(Palette.surfaceRaised, in: RoundedRectangle(cornerRadius: Metrics.corner))
        .overlay {
            RoundedRectangle(cornerRadius: Metrics.corner)
                .strokeBorder(Palette.border, lineWidth: Metrics.outline)
        }
        .contextMenu {
            if WorkSuggestionCard.opensAsDraft(suggestion) {
                Button("Open as Draft") {
                    Task { await app.openSuggestionAsDraft(suggestion) }
                }
                .disabled(isPressing)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(WorkSuggestionCard.accessibilityLabel(for: suggestion))
    }

    @ViewBuilder
    private func status(of suggestion: WorkSuggestion) -> some View {
        if let line = WorkSuggestionCard.statusLine(for: suggestion) {
            if WorkSuggestionCard.openTarget(for: suggestion) != nil {
                Button {
                    app.openStartedSuggestion(suggestion)
                } label: {
                    HStack(spacing: Metrics.spacingSmall) {
                        Text(line)
                        Image(systemName: "arrow.right").accessibilityHidden(true)
                    }
                }
                .buttonStyle(.plain)
                .font(Typo.caption)
                .foregroundStyle(Palette.link)
                .pointerStyle(.link)
            } else {
                Text(line)
                    .font(Typo.caption)
                    .foregroundStyle(suggestion.state == .pending ? Palette.negative : Palette.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private func offers(for suggestion: WorkSuggestion, in context: WorkSuggestionCard.Context) -> some View {
        let offers = WorkSuggestionCard.offers(for: suggestion, in: context)
        if !offers.isEmpty {
            HStack(spacing: Metrics.spacingWide) {
                ForEach(offers, id: \.action) { offer in
                    if offer.isProminent {
                        Button(offer.title) { press(offer.action, suggestion) }
                            .buttonStyle(.borderedProminent)
                            .accessibilityLabel(offer.accessibilityLabel)
                    } else {
                        Button(offer.title) { press(offer.action, suggestion) }
                            .buttonStyle(.bordered)
                            .accessibilityLabel(offer.accessibilityLabel)
                    }
                }
            }
            .controlSize(.small)
            .disabled(isPressing)
        }
    }

    private func press(_ action: WorkSuggestionCard.Action, _ suggestion: WorkSuggestion) {
        guard !isPressing else { return }
        isPressing = true
        Task {
            switch action {
            case .newWorkspace, .addProjectAndStart: await app.startSuggestion(suggestion.id, as: .newWorkspace)
            case .here: await app.startSuggestion(suggestion.id, as: .here)
            case .dismiss: await app.dismissSuggestion(suggestion.id)
            }
            isPressing = false
        }
    }
}
