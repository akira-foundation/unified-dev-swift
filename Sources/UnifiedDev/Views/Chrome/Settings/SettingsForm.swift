import SwiftUI

extension View {
    func settingsForm() -> some View {
        formStyle(.grouped)
            .hidesScrollEdgeRule()
            .modifier(SettingsLabelColumn())
    }
}

struct SettingsLabelColumn: ViewModifier {
    @State private var width: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .environment(\.settingsLabelColumn, width)
            .onPreferenceChange(SettingsLabelWidth.self) { width = $0 }
    }
}

struct SettingsLabelWidth: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

extension EnvironmentValues {
    @Entry var settingsLabelColumn: CGFloat = 0
}

extension View {
    func settingsFootnote() -> some View {
        font(Typo.caption)
            .foregroundStyle(Palette.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
