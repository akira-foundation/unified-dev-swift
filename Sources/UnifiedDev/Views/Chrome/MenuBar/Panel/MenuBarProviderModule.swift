import SwiftUI
import Core

struct MenuBarProviderModule: View {
    let provider: MenuBarPanelContent.Provider
    let section: UsageLayout.Section?
    let plan: String?
    let options: UsageDisplayOptions
    let now: Date
    var focus: FocusState<MenuBarPanelFocus?>.Binding?
    let retry: () -> Void
    let toggleFold: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingWide) {
            header
            switch provider.reading {
            case .unavailable: unavailable
            case .measured: meters
            }
        }
        .menuBarModule(provider.kind.label)
    }

    private var header: some View {
        HStack(spacing: Metrics.spacing) {
            ProviderMarkView(provider: provider.kind)
                .foregroundStyle(MenuInk.secondary)
                .frame(width: 15, height: 15)
            Text(provider.kind.label)
                .font(UsageScale.header)
                .foregroundStyle(MenuInk.primary)
                .accessibilityAddTraits(.isHeader)
            if let plan {
                Text(plan)
                    .font(UsageScale.plan)
                    .foregroundStyle(MenuInk.secondary)
            }
            Spacer(minLength: Metrics.spacingWide)
            if provider.reading == .measured, let section, !section.onDemand.isEmpty {
                Button(action: toggleFold) {
                    Image(systemName: section.isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(MenuInk.secondary)
                        .frame(width: 20, height: 16)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(section.isExpanded ? "Show fewer limits" : "Show more limits")
                .panelFocus(focus, .fold(provider.kind))
            }
        }
    }

    private var unavailable: some View {
        HStack(alignment: .firstTextBaseline, spacing: Metrics.spacingWide) {
            Text(MenuBarPanelContent.unavailableLine(for: provider.kind))
                .font(UsageScale.supporting)
                .foregroundStyle(MenuInk.secondary)
            Spacer(minLength: Metrics.spacingWide)
            Button(MenuBarPanelContent.retryTitle, action: retry)
                .linkButton()
                .panelFocus(focus, .retry(provider.kind))
        }
    }

    @ViewBuilder
    private var meters: some View {
        if let section {
            VStack(spacing: 0) {
                ForEach(Array(section.visible.enumerated()), id: \.element.id) { index, metric in
                    UsageMenuRow(
                        metric: metric,
                        now: now,
                        options: options,
                        isCondensed: index > 0 && section.visible[index - 1].isText && metric.isText
                    )
                }
            }
            .padding(.horizontal, -12)
        }
    }
}
