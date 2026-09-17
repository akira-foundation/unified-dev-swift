import SwiftUI
import Core

struct PromptEditor: View {
    let definition: PromptDefinition
    var onSave: () -> Void = {}

    private static let editorHeight: CGFloat = 220

    private static let focusRingWidth: CGFloat = 2

    private let overrides = PromptOverrides()

    @State private var showsVariables = false

    @State private var text = ""
    @State private var isLoaded = false

    @FocusState private var isFocused: Bool

    @Environment(\.controlActiveState) private var activeState

    private var isRingVisible: Bool { isFocused && activeState.showsFocusRing }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.gutter) {
            DisclosureGroup("When this prompt is used") {
                Text(definition.summary)
                    .settingsFootnote()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            editor

            HStack(spacing: Metrics.gutter) {
                status

                Spacer()

                Button("Restore default", action: restoreDefault)
                    .disabled(!isCustomised)
            }

            if !unknownVariables.isEmpty {
                Label(
                    "Not substituted: \(unknownVariables.map(PromptTemplate.token).joined(separator: ", "))",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(Typo.caption)
                .foregroundStyle(Palette.warning)
                .fixedSize(horizontal: false, vertical: true)
                .onAppear { showsVariables = true }
            }

            variableReference
        }
        .task { load() }
    }

    private var editor: some View {
        TextEditor(text: Binding(get: { text }, set: { value in
            text = value
            save(value)
        }))
            .font(Typo.codeSmall)
            .scrollContentBackground(.hidden)
            .padding(Metrics.spacingSmall)
            .frame(minHeight: Self.editorHeight)
            .focused($isFocused)
            .background(Palette.surfaceSunken, in: RoundedRectangle(cornerRadius: Metrics.cornerSmall))
            .overlay {
                RoundedRectangle(cornerRadius: Metrics.cornerSmall)
                    .strokeBorder(
                        isRingVisible ? Palette.focusRing : Palette.border,
                        lineWidth: isRingVisible ? Self.focusRingWidth : Metrics.outline
                    )
            }
            .accessibilityLabel("\(definition.title) prompt")
    }

    @ViewBuilder
    private var status: some View {
        if isEmptyOverride {
            Text("Empty, so the built-in prompt is sent.")
                .settingsFootnote()
        } else if isCustomised {
            Text("Customised")
                .settingsFootnote()
        }
    }

    private var variableReference: some View {
        DisclosureGroup(isExpanded: $showsVariables) {
            Grid(alignment: .leading, horizontalSpacing: Metrics.gutter, verticalSpacing: Metrics.spacingSmall) {
                ForEach(definition.variables) { variable in
                    GridRow {
                        Text(variable.token)
                            .font(Typo.codeSmall)
                            .foregroundStyle(Palette.textPrimary)
                            .textSelection(.enabled)

                        Text(variable.summary)
                            .settingsFootnote()
                    }
                }
            }
            .padding(.top, Metrics.spacingSmall)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text("Variables")
                .font(Typo.captionEmphasis)
                .foregroundStyle(Palette.textSecondary)
        }
    }

    private var isCustomised: Bool {
        text != definition.defaultTemplate
    }

    private var isEmptyOverride: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var unknownVariables: [String] {
        let declared = Set(definition.variables.map(\.name))
        return PromptTemplate.variableNames(in: text).filter { !declared.contains($0) }
    }

    private func load() {
        text = overrides.stored(for: definition.id) ?? definition.defaultTemplate
        isLoaded = true
    }

    private func save(_ value: String) {
        guard isLoaded else { return }
        overrides.set(value == definition.defaultTemplate ? nil : value, for: definition.id)
        onSave()
    }

    private func restoreDefault() {
        text = definition.defaultTemplate
        save(text)
    }
}
