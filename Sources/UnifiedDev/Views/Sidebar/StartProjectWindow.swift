import SwiftUI

struct StartProjectWindow: Scene {
    let model: AppModel

    static let id = "start-project"

    var body: some Scene {
        Window("Start a Project", id: Self.id) {
            StartProjectView()
                .environment(model)
                .windowRole(.utility)
        }
        .windowResizability(.contentSize)
        .restorationBehavior(.disabled)
    }
}
