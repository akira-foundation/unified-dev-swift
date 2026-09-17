import SwiftUI

struct URLHandler: ViewModifier {
    let app: AppModel

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .unifieddevHandleURL)) { note in
                if let url = note.object as? URL { DeepLink.open(url, in: app) }
            }
            .onOpenURL { url in
                DeepLink.open(url, in: app)
            }
    }
}

extension View {
    func handlesAppURLs(using app: AppModel) -> some View {
        modifier(URLHandler(app: app))
    }
}
