import Core
import SwiftUI

extension View {
    func settingsForm() -> some View {
        formStyle(.grouped)
            .hidesScrollEdgeRule()
            .modifier(SettingsLabelColumn())
            .modifier(SettingsColumnMargin())
            .disclosureGroupStyle(.wholeRow)
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

struct SettingsColumnMargin: ViewModifier {
    @Environment(\.settingsColumnWidth) private var column
    @State private var available = 0.0

    func body(content: Content) -> some View {
        content
            .contentMargins(
                .horizontal, SettingsColumn.sideMargin(in: available, column: column), for: .scrollContent
            )
            .onGeometryChange(for: Double.self) { $0.size.width } action: { available = $0 }
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
    @Entry var settingsColumnWidth: Double?
}

extension View {
    func settingsFootnote() -> some View {
        font(Typo.caption)
            .foregroundStyle(Palette.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
