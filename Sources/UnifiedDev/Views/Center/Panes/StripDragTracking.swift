import SwiftUI
import Core

struct StripDragTracking: ViewModifier {
    var content: PaneContent
    var space: String
    var onMeasure: (Double) -> Void
    var onBegin: () -> Void
    var onEnd: (Bool) -> Void

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: Double.self) { proxy in
                proxy.frame(in: .named(space)).midX
            } action: {
                onMeasure($0)
            }
            .onDragSessionUpdated { session in
                switch session.phase {
                case .initial, .active:
                    onBegin()
                case .ended(let operation):
                    onEnd(operation != .cancel && operation != .forbidden)
                case .dataTransferCompleted:
                    onEnd(true)
                default:
                    return
                }
            }
    }
}
