import SwiftUI

extension View {
    @ViewBuilder
    func fileBarLabelStyle(labelled: Bool) -> some View {
        if labelled {
            labelStyle(.titleAndIcon)
        } else {
            labelStyle(.iconOnly)
        }
    }
}
