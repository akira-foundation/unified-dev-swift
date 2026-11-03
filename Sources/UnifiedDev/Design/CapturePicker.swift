import SwiftUI

enum CapturePicker {
    enum Target: String, Sendable {
        case agentSettings
    }

    static let name = Notification.Name("unifieddev.capture.openPicker")

    @MainActor
    static func post(_ target: Target) {
        NotificationCenter.default.post(name: name, object: target.rawValue)
    }

    static func target(in notification: Notification) -> Target? {
        (notification.object as? String).flatMap(Target.init(rawValue:))
    }
}

extension View {
    @ViewBuilder
    func opensDuringCapture(_ target: CapturePicker.Target, _ isOpen: Binding<Bool>) -> some View {
        #if DEBUG
        onReceive(NotificationCenter.default.publisher(for: CapturePicker.name)) { notification in
            guard CapturePicker.target(in: notification) == target else { return }
            isOpen.wrappedValue = true
        }
        #else
        self
        #endif
    }
}
