import SwiftUI

struct SidebarRowLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Metrics.spacing) {
            configuration.icon
                .frame(width: SidebarMetrics.markColumn, height: Metrics.glyph)
            configuration.title
        }
    }
}
