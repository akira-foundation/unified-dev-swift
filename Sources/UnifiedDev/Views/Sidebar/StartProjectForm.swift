import SwiftUI
import Core

struct StartProjectForm: View {
    @Bindable var model: StartProjectModel
    var onChoose: () -> Void
    var onSubmit: () -> Void

    @FocusState private var isFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.gutter) {
            HStack(spacing: Metrics.spacingWide) {
                field
                Button("Choose\u{2026}", action: onChoose)
            }

            if !model.completions.isEmpty { completions }

            if let problem = model.identityProblem, model.verdict.makesACommit {
                Callout(text: problem, symbol: "exclamationmark.triangle.fill", tone: .warning)
            }

            StartProjectConsequenceBlock(
                said: model.consequence,
                home: model.home,
                onUseAlternative: model.use(alternative:)
            )
        }
        .task { isFieldFocused = true }
    }

    private var field: some View {
        TextField("Name it, or point at a folder", text: $model.typed)
            .textFieldStyle(.roundedBorder)
            .font(Typo.body)
            .focused($isFieldFocused)
            .disabled(!model.isLocationLoaded)
            .onKeyPress(.return) {
                guard let selected = model.selectedCompletion else { return .ignored }
                model.accept(completion: selected)
                return .handled
            }
            .onSubmit {
                guard let selected = model.selectedCompletion else { return onSubmit() }
                model.accept(completion: selected)
            }
            .onKeyPress(.downArrow) { model.moveSelection(by: 1) ? .handled : .ignored }
            .onKeyPress(.upArrow) { model.moveSelection(by: -1) ? .handled : .ignored }
            .onKeyPress(.tab) {
                guard !model.completions.isEmpty else { return .ignored }
                model.accept(completion: model.selectedCompletion ?? 0)
                return .handled
            }
            .onKeyPress(.escape) { model.clearCompletions() ? .handled : .ignored }
    }

    private var completions: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingSmall) {
            ForEach(Array(model.completions.enumerated()), id: \.element) { index, path in
                Button { model.accept(completion: index) } label: {
                    row(path, isSelected: model.selectedCompletion == index)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(NewProjectPlan.display(path, home: model.home))
            }
        }
    }

    private func row(_ path: String, isSelected: Bool) -> some View {
        HStack {
            Image(systemName: "folder")
            Text((path as NSString).lastPathComponent)
            Spacer()
            Text(NewProjectPlan.display(path, home: model.home))
                .foregroundStyle(Palette.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(Metrics.spacingSmall)
        .background(isSelected ? Palette.controlAccent.opacity(0.15) : .clear)
    }
}
