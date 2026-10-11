import Foundation
import Core

extension AppModel {
    func refreshProjectActivity() async {
        guard let store else { return }
        let loaded = (try? await store.projectActivity()) ?? [:]
        guard projectActivity != loaded else { return }
        projectActivity = loaded
    }
}
