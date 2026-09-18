import Foundation

public enum MenuBarPanelFocus: Hashable, Sendable {
    case keepAwake
    case keepAwakeOptions
    case keepAwakeChoice(KeepAwakeChoice)
    case keepAwakeSettings
    case setup
    case retry(AgentKind)
    case fold(AgentKind)
    case agent(WorkspaceID)
    case moreAgents
    case settings
    case quit

    public static func order(
        content: MenuBarPanelContent,
        showsKeepAwakeOptions: Bool
    ) -> [MenuBarPanelFocus] {
        var order: [MenuBarPanelFocus] = [.keepAwake, .keepAwakeOptions]
        if showsKeepAwakeOptions {
            order += KeepAwakeChoice.allCases.map { .keepAwakeChoice($0) }
            order.append(.keepAwakeSettings)
        }
        if content.needsSetup { order.append(.setup) }
        for provider in content.providers {
            switch provider.reading {
            case .unavailable: order.append(.retry(provider.kind))
            case .measured where provider.isFoldable: order.append(.fold(provider.kind))
            case .measured: break
            }
        }
        order += content.agents.map { .agent($0.id) }
        if content.moreAgents > 0 { order.append(.moreAgents) }
        return order + [.settings, .quit]
    }

    public static func step(
        from current: MenuBarPanelFocus?,
        by offset: Int,
        in order: [MenuBarPanelFocus]
    ) -> MenuBarPanelFocus? {
        guard !order.isEmpty else { return nil }
        guard let current, let index = order.firstIndex(of: current) else {
            return offset < 0 ? order.last : order.first
        }
        return order[min(max(index + offset, 0), order.count - 1)]
    }
}
