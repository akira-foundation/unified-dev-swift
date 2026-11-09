import SwiftUI
import Core

struct ComposerSettingsPanel: View {
    var controls: ComposerControls
    var models: [ComposerModelSection]
    var efforts: [ComposerOption]
    var outputStyles: [ComposerOption]
    var permissionModes: [ComposerOption]
    var orchestrates: Bool = false
    var account: ComposerAccountSection?
    var matchedPreset: ModelPreset?
    var suggestedPresetName: String
    var onModel: @MainActor (String) -> Void
    var onEffort: @MainActor (String) -> Void
    var onOutputStyle: @MainActor (String) -> Void
    var onPermissionMode: @MainActor (String) -> Void
    var onContextWindow: @MainActor (Int) -> Void
    var onInteractionMode: @MainActor (InteractionMode) -> Void = { _ in }
    var onOpenInNewChat: (@MainActor (AgentKind) -> Void)?
    var onChangeAccount: @MainActor () -> Void = {}
    var onSavePreset: @MainActor (String) -> Void

    private static let width: CGFloat = 300

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: Metrics.spacing) {
                settingRow("Model") { modelPicker }
                if let onOpenInNewChat, !newChatProviders.isEmpty {
                    settingRow("New chat") { newChatMenu(onOpenInNewChat) }
                }
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
                        selection: controls.runningPermissionMode(orchestrates: orchestrates).rawValue,
                        options: permissionModes,
                        onSelect: onPermissionMode
                    )
                }

                if controls.offersContextWindow {
                    settingRow("Context window") { contextWindowPicker }
                }

                if let account {
                    accountRow(account)
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

    @ViewBuilder
    private func accountRow(_ account: ComposerAccountSection) -> some View {
        settingRow(ComposerAccountSection.heading) {
            HStack(spacing: Metrics.spacingSmall) {
                if account.warns {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Palette.warning)
                }
                Text(account.title)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Button(ComposerAccountSection.change) { onChangeAccount() }
                    .controlSize(.small)
            }
        }
        .help(account.sentence)
        if account.warns {
            Text(account.sentence)
                .font(Typo.caption)
                .foregroundStyle(Palette.warning)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var newChatProviders: [AgentKind] {
        BackendChange.newChatProviders(from: controls.agentKind, offered: models.map(\.kind))
    }

    private func newChatMenu(_ open: @escaping @MainActor (AgentKind) -> Void) -> some View {
        Menu("Choose an agent") {
            ForEach(newChatProviders, id: \.self) { kind in
                Button(BackendChange.newChatLabel(to: kind)) { open(kind) }
            }
        }
        .controlSize(.small)
        .fixedSize()
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
