import SwiftUI
import Core

struct SearchPanelScopes: View {
    var counts: HomeScopeCounts
    @Binding var scope: HomeScope

    var body: some View {
        GlassEffectContainer(spacing: Metrics.spacingSmall) {
            HStack(spacing: Metrics.spacingSmall) {
                ForEach(HomeScope.offered(searching: true), id: \.self) { offered in
                    ScopeChip(
                        label: offered.label(searching: true),
                        count: counts.count(of: offered, searching: true),
                        isOn: offered == scope
                    ) {
                        scope = offered
                    }
                }

                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, Metrics.inset)
        .padding(.bottom, Metrics.spacingSmall)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Choose which kind of thing the answer is narrowed to")
    }
}

private struct ScopeChip: View {
    var label: String
    var count: Int
    var isOn: Bool
    var pick: @MainActor () -> Void

    @Environment(\.controlActiveState) private var activeState
    @State private var isHovered = false

    var body: some View {
        Button(action: pick) {
            HStack(spacing: Metrics.spacing) {
                Text(label)
                    .font(Typo.caption)
                    .lineLimit(1)
                    .fixedSize()

                CountLabel(count: count, isOnSelection: isEmphasized)
            }
            .foregroundStyle(isEmphasized ? Palette.selectedEmphasizedText : Palette.textSecondary)
            .padding(.horizontal, Metrics.gutter)
            .frame(height: Metrics.controlHeight)
            .background(fill, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.glass)
        .onHoverChange { isHovered = $0 }
        .accessibilityLabel("\(label), \(count)")
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }

    private var isEmphasized: Bool {
        isOn && activeState != .inactive
    }

    private var fill: Color {
        if isEmphasized { return Palette.selectedEmphasized }
        if isOn { return Palette.selected }
        return isHovered ? Palette.hover : .clear
    }
}
