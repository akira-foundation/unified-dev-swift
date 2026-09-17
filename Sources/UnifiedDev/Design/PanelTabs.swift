import SwiftUI

struct PanelTabs<Tab: Hashable>: View {
    var label: String
    var tabs: [Tab]
    @Binding var selection: Tab
    var title: (Tab) -> String
    var hovering: Tab?

    init(
        _ label: String,
        tabs: [Tab],
        selection: Binding<Tab>,
        title: @escaping (Tab) -> String,
        hovering: Tab? = nil
    ) {
        self.label = label
        self.tabs = tabs
        self._selection = selection
        self.title = title
        self.hovering = hovering
    }

    @State private var pointer: Tab?
    @Namespace private var pill

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.self) { tab in
                cell(tab)
            }
        }
        .padding(Metrics.spacingTight)
        .background {
            RoundedRectangle(cornerRadius: Metrics.corner)
                .fill(Palette.surfaceSunken)
        }
        .overlay {
            RoundedRectangle(cornerRadius: Metrics.corner)
                .strokeBorder(Palette.border, lineWidth: Metrics.outline)
        }
        .animation(reduceMotion ? nil : Motion.pane, value: selection)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
    }

    private func cell(_ tab: Tab) -> some View {
        let isSelected = tab == selection
        let isHovered = (hovering ?? pointer) == tab && !isSelected
        return Button {
            selection = tab
        } label: {
            Text(title(tab))
                .font(isSelected ? Typo.labelEmphasis : Typo.label)
                .foregroundStyle(ink(selected: isSelected, hovered: isHovered))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Metrics.spacingSmall)
                .padding(.horizontal, Metrics.spacingSmall)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: Metrics.cornerSmall)
                            .fill(Palette.selected)
                            .matchedGeometryEffect(id: "tabstrip.pill", in: pill)
                    } else if isHovered {
                        RoundedRectangle(cornerRadius: Metrics.cornerSmall)
                            .fill(Palette.hover)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { inside in
            withAnimation(reduceMotion ? nil : Motion.hover) {
                pointer = inside ? tab : (pointer == tab ? nil : pointer)
            }
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func ink(selected: Bool, hovered: Bool) -> Color {
        selected || hovered ? Palette.textPrimary : Palette.textTertiary
    }
}
