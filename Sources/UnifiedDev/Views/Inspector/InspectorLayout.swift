import SwiftUI

enum InspectorLayout {
    static let tight = Metrics.spacingTight
    static let gap = Metrics.spacing
    static let inset = Metrics.inset
    static let barHeight = Metrics.barHeight
    static let reviewHeaderHeight: CGFloat = 40
    static let pullRequestBarHeight: CGFloat = 48
    static let viewedOpacity: Double = 0.55
    static let tintOpacity: Double = 0.12
    static let bandOpacity: Double = 0.18
    static let bandOpacityQuiet: Double = 0.08
    static let glyphWidth: CGFloat = 16
    static let indentStep: CGFloat = 16
}

extension View {
    func inspectorBarControl() -> some View {
        buttonStyle(.bordered)
            .controlSize(.small)
    }
}
