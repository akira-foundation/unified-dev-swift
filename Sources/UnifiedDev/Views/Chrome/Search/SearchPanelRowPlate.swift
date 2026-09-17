import SwiftUI

enum SearchPanelRowMetrics {
    static let plateInset: CGFloat = Metrics.spacing

    static let contentInset: CGFloat = Metrics.inset - plateInset

    static let air: CGFloat = Metrics.spacing

    static let gap: CGFloat = Metrics.spacingTight

    static let lineGap: CGFloat = Metrics.spacingTight
}

extension View {
    func searchPanelRowPadding() -> some View {
        padding(.horizontal, SearchPanelRowMetrics.contentInset)
            .padding(.vertical, SearchPanelRowMetrics.air)
    }

    func searchPanelRowPlate(isSelected: Bool, isHovered: Bool) -> some View {
        rowBackground(isSelected: isSelected, isHovered: isHovered, isFocused: false)
            .padding(.horizontal, SearchPanelRowMetrics.plateInset)
    }
}
