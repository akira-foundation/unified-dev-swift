import SwiftUI

private struct CanvasBarItem<Label: View>: View {
    let label: Label
    let isOn: Bool
    let isPressed: Bool

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    var body: some View {
        label
            .font(.system(size: 14))
            .foregroundStyle(foreground)
            .frame(minWidth: 28, minHeight: 28)
            .background(fill, in: Capsule())
            .contentShape(Capsule())
            .opacity(isEnabled ? 1 : 0.4)
            .onHoverChange { isHovered = $0 }
            .animation(Motion.hover, value: isHovered)
    }

    private var foreground: Color {
        isOn ? .white : .primary
    }

    private var fill: Color {
        if isOn { return .accentColor }
        guard isEnabled else { return .clear }
        if isPressed { return .primary.opacity(0.2) }
        return isHovered ? .primary.opacity(0.12) : .clear
    }
}

struct CanvasBarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        CanvasBarItem(label: configuration.label, isOn: false, isPressed: configuration.isPressed)
    }
}

struct CanvasBarToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            CanvasBarItem(label: configuration.label, isOn: configuration.isOn, isPressed: false)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(configuration.isOn ? .isSelected : [])
    }
}

struct CanvasBarMenu<Content: View>: View {
    let symbol: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        Menu(content: content) {
            Image(systemName: symbol)
        }
        .menuStyle(.button)
        .buttonStyle(CanvasBarButtonStyle())
        .menuIndicator(.hidden)
        .fixedSize()
    }
}

struct CanvasBarDivider: View {
    var body: some View {
        Divider()
            .frame(height: 18)
            .padding(.horizontal, 6)
    }
}

extension View {
    func canvasBarBackground() -> some View {
        padding(5)
            .glassEffect(.regular, in: Capsule())
    }
}
