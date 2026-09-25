import SwiftUI
import Core

struct ComposerSettingsPicker: View {
    var controls: ComposerControls
    var models: [ComposerModelSection]
    var efforts: [ComposerOption]
    var outputStyles: [ComposerOption]
    var permissionModes: [ComposerOption]
    var isCompact: Bool
    var onModel: @MainActor (String) -> Void
    var onEffort: @MainActor (String) -> Void
    var onOutputStyle: @MainActor (String) -> Void
    var onPermissionMode: @MainActor (String) -> Void
    var onContextWindow: @MainActor (Int) -> Void
    var onInteractionMode: @MainActor (InteractionMode) -> Void = { _ in }

    @State private var isOpen = false

    var body: some View {
        Button { isOpen = true } label: {
            ComposerControlLabel(
                systemImage: "slider.horizontal.3",
                text: isCompact ? nil : controls.settingsLabel(model: modelLabel),
                tint: Palette.textSecondary,
                isActive: isOpen,
                showsMenuIndicator: true
            )
        }
        .fixedSize(horizontal: false, vertical: true)
        .help("Agent settings")
        .accessibilityLabel("Agent settings")
        .accessibilityValue(summary)
        .popover(isPresented: $isOpen, arrowEdge: .top) {
            ComposerSettingsPanel(
                controls: controls,
                models: models,
                efforts: efforts,
                outputStyles: outputStyles,
                permissionModes: permissionModes,
                onModel: onModel,
                onEffort: onEffort,
                onOutputStyle: onOutputStyle,
                onPermissionMode: onPermissionMode,
                onContextWindow: onContextWindow,
                onInteractionMode: onInteractionMode
            )
            .environment(\.fontScale, 1)
        }
    }

    private var allModels: [ComposerOption] { models.flatMap(\.options) }

    private var modelLabel: String {
        ComposerOption.label(for: controls.model, in: allModels)
    }

    private var summary: String {
        let effort = ComposerOption.label(for: controls.effort, in: efforts)
        return "\(controls.settingsLabel(model: modelLabel)), \(effort), \(controls.permissionMode.label)"
    }
}

private struct ComposerSettingsPanel: View {
    var controls: ComposerControls
    var models: [ComposerModelSection]
    var efforts: [ComposerOption]
    var outputStyles: [ComposerOption]
    var permissionModes: [ComposerOption]
    var onModel: @MainActor (String) -> Void
    var onEffort: @MainActor (String) -> Void
    var onOutputStyle: @MainActor (String) -> Void
    var onPermissionMode: @MainActor (String) -> Void
    var onContextWindow: @MainActor (Int) -> Void
    var onInteractionMode: @MainActor (InteractionMode) -> Void = { _ in }

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
                    settingRow("Work mode") {
                        if ComposerPlanningSupport.shared.isAvailable {
                            optionPicker(
                                "Work mode", selection: controls.interactionMode.rawValue,
                                options: InteractionMode.allCases.map { ComposerOption(id: $0.rawValue, label: $0.label) },
                                onSelect: { value in
                                    if let mode = InteractionMode(rawValue: value) { onInteractionMode(mode) }
                                }
                            )
                        } else if controls.interactionMode == .plan {
                            Button("Use Build") { onInteractionMode(.build) }
                        } else {
                            Text("Build")
                        }
                    }
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
        }
        .frame(width: Self.width)
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
