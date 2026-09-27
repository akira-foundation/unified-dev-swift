import Foundation

public extension AppDefaults {
    func applying(_ preset: ModelPreset) -> AppDefaults {
        var next = self
        next.model = preset.model
        next.storedModel = preset.model
        next.effort = preset.effort
        next.storedEffort = preset.effort
        next.backend = preset.backend
        if preset.backend.offersOutputStyle { next.outputStyle = preset.outputStyle }
        next.permissionMode = preset.permissionMode
        next.planMode = preset.permissionMode == .plan
        return next
    }

    static func loadForNewSessions(from store: Store) async -> AppDefaults {
        let defaults = await load(from: store)
        guard let preset = await ModelPresetList.load(from: store).defaultPreset else { return defaults }
        return defaults.applying(preset)
    }
}
