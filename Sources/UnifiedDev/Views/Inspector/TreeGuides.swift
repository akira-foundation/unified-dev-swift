import SwiftUI

struct TreeGuides: View {
    var depth: Int

    static func indent(for depth: Int) -> CGFloat {
        CGFloat(max(depth, 0)) * InspectorLayout.indentStep
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<max(depth, 0), id: \.self) { _ in
                Rectangle()
                    .fill(.tertiary)
                    .frame(width: Metrics.hairline)
                    .frame(width: InspectorLayout.indentStep, alignment: .leading)
            }
        }
        .padding(.leading, InspectorLayout.gap)
        .accessibilityHidden(true)
    }
}

extension View {
    func treeIndent(depth: Int) -> some View {
        padding(.leading, TreeGuides.indent(for: depth) + InspectorLayout.gap)
            .padding(.trailing, InspectorLayout.gap)
            .frame(height: Metrics.rowHeight)
            .background(alignment: .leading) { TreeGuides(depth: depth) }
    }
}
