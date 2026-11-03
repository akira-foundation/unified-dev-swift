import SwiftUI

struct SidebarRowLabelStyle: LabelStyle {
    var showsMark = true

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: SidebarMetrics.markGap) {
            if showsMark {
                configuration.icon
                    .frame(width: SidebarMetrics.markColumn, height: Metrics.glyph)
            }
            configuration.title
        }
    }
}
