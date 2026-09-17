import SwiftUI
import Core

struct ComposerPickerGallery: View {
    var app: AppModel

    @State private var styleCatalog = ComposerOutputStyleCatalog()

    private var outputStyles: [ComposerOption] {
        styleCatalog.options(includingCurrent: "Concise")
    }

    private func permissionOptions(on kind: AgentKind) -> [ComposerOption] {
        ComposerControls(agentKind: kind).permissionModeChoices.map {
            ComposerOption(id: $0.mode.rawValue, label: $0.label, detail: $0.summary)
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: Metrics.pane) {
            VStack(alignment: .leading, spacing: Metrics.pane) {
                panel(
                    "Claude Code, on the widest mode there is",
                    options: permissionOptions(on: .claudeCode),
                    selection: PermissionMode.bypassPermissions.rawValue,
                    heading: "Permission mode"
                )
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: Metrics.pane) {
                panel(
                    "Codex, which has no Plan row and says nothing about it",
                    options: permissionOptions(on: .codex),
                    selection: PermissionMode.auto.rawValue,
                    heading: "Permission mode"
                )
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: Metrics.pane) {
                panel(
                    "Ask Unified Dev, where the footnote is the one thing left in it",
                    options: permissionOptions(on: .claudeCode),
                    selection: PermissionMode.auto.rawValue,
                    heading: "Permission mode",
                    footnote: ComposerControls(hasWorktree: false).permissionModeNote
                )
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: Metrics.pane) {
                panel(
                    "Output styles, in the CLI's own words",
                    options: outputStyles,
                    selection: "Concise",
                    heading: "Output style"
                )
                captioned("The chips these hang off, in both widths") { chips }
                Spacer(minLength: 0)
            }
        }
        .padding(Metrics.pane)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.surface)
        .environment(app)
    }

    private func panel(
        _ caption: String,
        options: [ComposerOption],
        selection: String,
        heading: String,
        footnote: String? = nil
    ) -> some View {
        captioned(caption) {
            ComposerOptionList(
                options: options,
                footnote: footnote,
                selection: selection,
                heading: heading,
                onSelect: { _ in },
                onClose: {}
            )
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metrics.corner + 2))
            .overlay {
                RoundedRectangle(cornerRadius: Metrics.corner + 2)
                    .strokeBorder(Palette.border, lineWidth: Metrics.hairline)
            }
        }
    }

    private var chips: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingWide) {
            ForEach([false, true], id: \.self) { isCompact in
                HStack(spacing: Metrics.spacingTight) {
                    ComposerOptionPicker(
                        options: outputStyles,
                        selection: "Concise",
                        heading: "Output style",
                        systemImage: "textformat",
                        isCompact: isCompact,
                        help: "Choose the output style",
                        onSelect: { _ in }
                    )
                    ComposerOptionPicker(
                        options: permissionOptions(on: .claudeCode),
                        selection: PermissionMode.auto.rawValue,
                        heading: "Permission mode",
                        systemImage: "hand.raised",
                        isCompact: isCompact,
                        help: "Choose permission mode",
                        onSelect: { _ in }
                    )
                    ComposerOptionPicker(
                        options: permissionOptions(on: .claudeCode),
                        selection: PermissionMode.bypassPermissions.rawValue,
                        heading: "Permission mode",
                        systemImage: "exclamationmark.shield",
                        tint: Palette.warning,
                        isCompact: isCompact,
                        help: "Choose permission mode",
                        onSelect: { _ in }
                    )
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(width: ComposerOptionList.width)
    }

    private func captioned(_ caption: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Metrics.spacingWide) {
            Text(caption)
                .font(Typo.caption)
                .foregroundStyle(Palette.textTertiary)
            content()
        }
    }
}

extension Gallery {
    static let composerPickers = Gallery(
        name: "composer-pickers",
        title: "Composer pickers",
        size: CGSize(width: 1680, height: 1000),
        needsFocus: false,
        view: { app in AnyView(ComposerPickerGallery(app: app)) }
    )
}
