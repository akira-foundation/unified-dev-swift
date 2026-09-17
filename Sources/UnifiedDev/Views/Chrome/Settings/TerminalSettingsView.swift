import AppKit
import SwiftUI
import Core

struct TerminalSettingsView: View {
    @AppStorage(TerminalGhostty.defaultsKey) private var usesGhosttyTheme = true
    @AppStorage(TerminalTextSize.defaultsKey) private var terminalFontSize = 0.0
    @AppStorage(TerminalPersistence.defaultsKey) private var persistsTerminals = false

    var body: some View {
        Form {
            Section {
                Toggle("Use Ghostty terminal theme", isOn: $usesGhosttyTheme)
                    .help("Reads the font and colours from your Ghostty configuration. Off uses Unified Dev's own palette.")

                SettingsRow("Text size") {
                    HStack(spacing: Metrics.gutter) {
                        Stepper(value: sizeBinding, in: TerminalTextSize.range, step: TerminalTextSize.step) {
                            Text("\(Int(effectiveTerminalSize)) pt")
                                .monospacedDigit()
                        }
                        .fixedSize()

                        Button("Use Default") { TerminalTextSize.override = nil }
                            .disabled(terminalFontSize == 0)
                    }
                }

                TerminalTextPreview(size: effectiveTerminalSize, usesGhosttyTheme: usesGhosttyTheme)
            } header: {
                Text("Appearance")
            } footer: {
                Text(terminalSizeSource)
                    .settingsFootnote()
            }

            Section {
                Toggle("Keep terminals running after quitting", isOn: $persistsTerminals)
                    .disabled(!TerminalPersistence.isTmuxInstalled)
                    .help(
                        "Terminals run in tmux instead of inside Unified Dev, so they survive a quit "
                        + "and come back on the next launch."
                    )
            } header: {
                Text("After quitting Unified Dev")
            } footer: {
                Text(TerminalSettingsCopy.persistence(isTmuxInstalled: TerminalPersistence.isTmuxInstalled))
                    .settingsFootnote()
            }
        }
        .settingsForm()
    }

    private var sizeBinding: Binding<CGFloat> {
        Binding(
            get: { effectiveTerminalSize },
            set: { TerminalTextSize.override = $0 }
        )
    }

    private var effectiveTerminalSize: CGFloat {
        TerminalTextSize.override ?? TerminalTextSize.fallback(for: NSApp.effectiveAppearance)
    }

    private var terminalSizeSource: String {
        TerminalSettingsCopy.textSizeSource(
            override: TerminalTextSize.override.map { Double($0) },
            ghostty: TerminalTextSize.ghosttyDefault(for: NSApp.effectiveAppearance).map { Double($0) }
        )
    }
}

private struct TerminalTextPreview: View {
    var size: CGFloat
    var usesGhosttyTheme: Bool

    private var font: NSFont {
        let family = usesGhosttyTheme
            ? TerminalGhostty.theme(for: NSApp.effectiveAppearance)?.fontFamily
            : nil
        return TerminalGhostty.font(family: family, size: size)
    }

    var body: some View {
        Text(verbatim: "~/dev/unifieddev (main) $ swift build --product UnifiedDev")
            .font(Font(font))
            .lineLimit(1)
            .truncationMode(.tail)
            .foregroundStyle(Palette.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Metrics.inset)
            .background(Palette.surfaceSunken, in: RoundedRectangle(cornerRadius: Metrics.corner))
            .accessibilityLabel("Preview of a terminal at this text size")
    }
}
