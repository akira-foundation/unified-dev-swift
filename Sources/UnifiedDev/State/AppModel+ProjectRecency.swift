import Foundation
import Core

extension AppModel {
    func refreshProjectActivity() async {
        guard let store, let loaded = try? await store.projectActivity() else { return }
        guard projectActivity != loaded else { return }
        projectActivity = loaded
    }
}
