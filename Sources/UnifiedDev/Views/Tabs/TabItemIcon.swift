import AppKit
import SwiftUI
import Core

enum TabItemIcon: Equatable {
    case symbol(String)
    case page(NSImage?)
}

struct TabItemIconView: View {
    var icon: TabItemIcon
    var ink: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let pageSize: CGFloat = 14

    var body: some View {
        switch icon {
        case .symbol(let name):
            Image(systemName: name)
                .imageScale(.small)
                .foregroundStyle(ink)
        case .page(let image):
            Group {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                } else {
                    Image(systemName: PaneGlyph.browser)
                        .imageScale(.small)
                        .foregroundStyle(ink)
                }
            }
            .frame(width: Self.pageSize, height: Self.pageSize)
            .clipped()
            .animation(reduceMotion ? nil : Motion.hover, value: image != nil)
        }
    }
}
