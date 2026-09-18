import Foundation
import Core

extension KeepAwakeModel {
    func perform(_ actions: [KeepAwakeChip.Action], defaults: UserDefaults = .standard) {
        for action in actions {
            switch action {
            case .start(let seconds): start(for: seconds)
            case .stop: stop()
            case .setWhileAgentsRun(let isOn): defaults.set(isOn, forKey: SleepPrevention.settingKey)
            }
        }
    }
}
