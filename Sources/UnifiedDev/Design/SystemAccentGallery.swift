import SwiftUI
import Core

struct SystemAccentGallery: View {
    var app: AppModel

    var body: some View {
        HStack(alignment: .top, spacing: Metrics.pane) {
            VStack(alignment: .leading, spacing: Metrics.pane) {
                captioned("What AppKit draws off the accent, and no .tint can reach") {
                    SystemAccentControls()
                        .environment(\.controlActiveState, .key)
                }
                Spacer(minLength: 0)
            }
            .frame(width: 300)

            VStack(alignment: .leading, spacing: Metrics.pane) {
                captioned("What AppKit derives from it") {
                    VStack(alignment: .leading, spacing: Metrics.spacingWide) {
                        swatch(
                            "controlAccentColor",
                            Palette.controlAccent,
                            ink: Palette.selectedEmphasizedText
                        )
                        swatch(
                            "keyboardFocusIndicatorColor",
                            Palette.focusRing,
                            ink: Color(nsColor: .labelColor)
                        )
                        swatch(
                            "selectedTextBackgroundColor",
                            Palette.textSelection,
                            ink: Color(nsColor: .selectedTextColor)
                        )
                        swatch(
                            "selectedContentBackgroundColor",
                            Color(nsColor: .selectedContentBackgroundColor),
                            ink: Color(nsColor: .alternateSelectedControlTextColor)
                        )
                    }
                }

                captioned("What Unified Dev draws itself") {
                    VStack(alignment: .leading, spacing: Metrics.spacingWide) {
                        swatch(
                            "Palette.selectedEmphasized",
                            Palette.selectedEmphasized,
                            ink: Palette.selectedEmphasizedText
                        )
                        swatch("Palette.accentFill", Palette.accentFill, ink: Palette.textInverted)
                        swatch("Palette.selected", Palette.selected, ink: Palette.textPrimary)
                        HStack(spacing: Metrics.spacingWide) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(Palette.accent)
                            Text("Palette.accent, the ink half of the ramp")
                                .font(Typo.caption)
                                .foregroundStyle(Palette.accent)
                        }
                    }
                }

                captioned("The one this page cannot answer: grey here, accent in a key window") {
                    SystemAccentSegments()
                }

                Spacer(minLength: 0)
            }
        }
        .padding(Metrics.pane)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.surface)
        .environment(app)
    }

    private func swatch(_ name: String, _ fill: Color, ink: Color) -> some View {
        Text(name)
            .font(Typo.caption)
            .foregroundStyle(ink)
            .padding(.horizontal, Metrics.gutter)
            .padding(.vertical, Metrics.spacingWide)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill, in: .rect(cornerRadius: Metrics.cornerSmall))
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

private struct SystemAccentControls: View {
    @State private var switchOn = true
    @State private var switchOff = false
    @State private var boxOn = true
    @State private var boxOff = false
    @State private var choice = 1
    @State private var slider = 0.65
    @State private var steps = 3

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.gutter) {
            Toggle("A switch, on", isOn: $switchOn)
                .toggleStyle(.switch)
            Toggle("A switch, off", isOn: $switchOff)
                .toggleStyle(.switch)

            Toggle("A tick box, ticked", isOn: $boxOn)
                .toggleStyle(.checkbox)
            Toggle("A tick box, clear", isOn: $boxOff)
                .toggleStyle(.checkbox)

            Picker("", selection: $choice) {
                Text("A radio, unchosen").tag(0)
                Text("A radio, chosen").tag(1)
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()

            Slider(value: $slider)

            ProgressView(value: slider)

            Stepper("A stepper at \(steps)", value: $steps, in: 0...9)

            HStack(spacing: Metrics.spacingWide) {
                Button("Prominent") {}
                    .buttonStyle(.borderedProminent)
                Button("Bordered") {}
                    .buttonStyle(.bordered)
            }
        }
    }
}

private struct SystemAccentSegments: View {
    @State private var segment = 0

    var body: some View {
        Picker("", selection: $segment) {
            Text("Diff").tag(0)
            Text("Files").tag(1)
            Text("Checks").tag(2)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: 260)
    }
}

extension Gallery {
    static let systemAccent = Gallery(
        name: "system-accent",
        title: "System accent",
        size: CGSize(width: 820, height: 620),
        needsFocus: false,
        view: { app in AnyView(SystemAccentGallery(app: app)) }
    )
}
