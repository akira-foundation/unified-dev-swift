import SwiftUI
import Core

struct ComposerSettingsPicker: View {
    var controls: ComposerControls
    var models: [ComposerModelSection]
    var catalogModels: [AgentKind: [AgentModel]]
    var efforts: [ComposerOption]
    var outputStyles: [ComposerOption]
    var permissionModes: [ComposerOption]
    var isCompact: Bool
    var onPreset: @MainActor (ModelPreset) -> Void
    var onModel: @MainActor (String) -> Void
    var onEffort: @MainActor (String) -> Void
    var onOutputStyle: @MainActor (String) -> Void
    var onPermissionMode: @MainActor (String) -> Void
    var onContextWindow: @MainActor (Int) -> Void
    var onInteractionMode: @MainActor (InteractionMode) -> Void = { _ in }

    @Environment(AppModel.self) private var app
    @State private var isOpen = false

    private var library: ModelPresetLibrary { .shared }

    var body: some View {
        let summary = ComposerPresetSummary(
            controls: controls, presets: library.list, modelLabel: modelLabel,
            effortLabel: effortLabel, models: catalogModels
        )

        Group {
            if library.presets.isEmpty {
                Button { isOpen = true } label: { settingsLabel(summary) }
            } else {
                ComposerPresetMenu(
                    presets: library.presets,
                    matched: summary.matched,
                    onPreset: onPreset,
                    onCustom: { DispatchQueue.main.async { isOpen = true } },
                    onManage: managePresets
                ) {
                    settingsLabel(summary)
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .help(summary.help)
        .accessibilityLabel("Agent settings")
        .accessibilityValue(controls.settingsLabel(model: summary.accessibilityValue))
        .popover(isPresented: $isOpen, arrowEdge: .top) {
            ComposerSettingsPanel(
                controls: controls,
                models: models,
                efforts: efforts,
                outputStyles: outputStyles,
                permissionModes: permissionModes,
                matchedPreset: summary.matched,
                suggestedPresetName: summary.suggestedName,
                onModel: onModel,
                onEffort: onEffort,
                onOutputStyle: onOutputStyle,
                onPermissionMode: onPermissionMode,
                onContextWindow: onContextWindow,
                onInteractionMode: onInteractionMode,
                onSavePreset: savePreset
            )
            .environment(\.fontScale, 1)
        }
        .task { await library.load(from: app.store) }
    }

    private func settingsLabel(_ summary: ComposerPresetSummary) -> some View {
        ComposerControlLabel(
            systemImage: "slider.horizontal.3",
            text: isCompact ? nil : controls.settingsLabel(model: summary.title),
            tint: Palette.textSecondary,
            isActive: isOpen,
            showsMenuIndicator: true,
            showsDot: summary.isOneOff
        )
    }

    private var allModels: [ComposerOption] { models.flatMap(\.options) }

    private var modelLabel: String {
        ComposerOption.label(for: controls.model, in: allModels)
    }

    private var effortLabel: String {
        ComposerOption.label(for: controls.effort, in: efforts)
    }

    private func managePresets() {
        SettingsTabRequest.post(.presets)
        SettingsWindow.open()
    }

    private func savePreset(_ name: String) {
        guard let name = ModelPreset.cleanName(name) else { return }
        isOpen = false
        library.add(ModelPreset(name: name, controls: controls), in: app.store)
    }
}

private struct ComposerSettingsPanel: View {
    var controls: ComposerControls
    var models: [ComposerModelSection]
    var efforts: [ComposerOption]
    var outputStyles: [ComposerOption]
    var permissionModes: [ComposerOption]
    var matchedPreset: ModelPreset?
    var suggestedPresetName: String
    var onModel: @MainActor (String) -> Void
    var onEffort: @MainActor (String) -> Void
    var onOutputStyle: @MainActor (String) -> Void
    var onPermissionMode: @MainActor (String) -> Void
    var onContextWindow: @MainActor (Int) -> Void
    var onInteractionMode: @MainActor (InteractionMode) -> Void = { _ in }
    var onSavePreset: @MainActor (String) -> Void

    private static let width: CGFloat = 300

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: Metrics.spacing) {
                settingRow("Model") { modelPicker }
                settingRow("Reasoning") {
                    optionPicker("Reasoning", selection: controls.effort, options: efforts, onSelect: onEffort)
                }

                if controls.offersOutputStyle {
                    settingRow("Output style") {
                        optionPicker(
                            "Output style",
                            selection: controls.outputStyle,
                            options: outputStyles,
                            onSelect: onOutputStyle
                        )
                    }
                }

                if controls.offersInteractionMode {
                    settingRow("Work mode") { workMode }
                    if !ComposerPlanningSupport.shared.isAvailable {
                        Text(CodexPlanningCapability.explanation).font(Typo.caption)
                        Button("Check Again") { Task { await ComposerPlanningSupport.shared.checkAgain() } }
                            .disabled(ComposerPlanningSupport.shared.isChecking)
                    }
                }

                settingRow("Permissions") {
                    optionPicker(
                        "Permissions",
                        selection: controls.permissionMode.rawValue,
                        options: permissionModes,
                        onSelect: onPermissionMode
                    )
                }

                if controls.offersContextWindow {
                    settingRow("Context window") { contextWindowPicker }
                }
            }
            .padding(Metrics.gutter)

            Hairline()

            ComposerPresetSaveRow(
                matchedPreset: matchedPreset,
                suggestedName: suggestedPresetName,
                onSave: onSavePreset
            )
        }
        .frame(width: Self.width)
    }

    @ViewBuilder
    private var workMode: some View {
        switch ComposerWorkModeRow(
            isPlanningAvailable: ComposerPlanningSupport.shared.isAvailable,
            interactionMode: controls.interactionMode
        ) {
        case .choice:
            optionPicker(
                "Work mode", selection: controls.interactionMode.rawValue,
                options: InteractionMode.allCases.map { ComposerOption(id: $0.rawValue, label: $0.label) },
                onSelect: { value in
                    if let mode = InteractionMode(rawValue: value) { onInteractionMode(mode) }
                }
            )
        case .offerBuild:
            Button("Use Build") { onInteractionMode(.build) }
        case .build:
            Text("Build")
        }
    }

    private func settingRow<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: Metrics.spacing) {
            Text(title)
                .font(Typo.label)
                .foregroundStyle(Palette.textSecondary)

            Spacer(minLength: Metrics.spacing)

            content()
        }
        .frame(minHeight: Metrics.rowHeight)
    }

    private var modelPicker: some View {
        Picker("Model", selection: modelBinding) {
            ForEach(models) { section in
                Section(section.title) {
                    ForEach(section.options) { option in
                        Text(option.menuLabel).tag(option.id)
                    }
                }
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .controlSize(.small)
    }

    private func optionPicker(
        _ title: String,
        selection: String,
        options: [ComposerOption],
        onSelect: @escaping @MainActor (String) -> Void
    ) -> some View {
        Picker(title, selection: Binding(
            get: { selection },
            set: { id in MainActor.assumeIsolated { onSelect(id) } }
        )) {
            ForEach(options) { option in
                Text(option.label).tag(option.id)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .controlSize(.small)
    }

    private var contextWindowPicker: some View {
        Picker("Context window", selection: contextWindowBinding) {
            ForEach(CodexContextWindow.options(including: controls.codexContextWindow), id: \.self) { tokens in
                Text(CodexContextWindow.label(for: tokens)).tag(tokens)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .controlSize(.small)
    }

    private var contextWindowBinding: Binding<Int> {
        Binding(
            get: { controls.codexContextWindow },
            set: { tokens in MainActor.assumeIsolated { onContextWindow(tokens) } }
        )
    }

    private var modelBinding: Binding<String> {
        Binding(get: { controls.model }, set: { id in MainActor.assumeIsolated { onModel(id) } })
    }
}
