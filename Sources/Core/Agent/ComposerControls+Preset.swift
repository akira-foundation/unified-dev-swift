import Foundation

public extension ComposerControls {
    func applying(_ preset: ModelPreset, models: [AgentKind: [AgentModel]] = [:]) -> ComposerControls {
        var next = self
        next.agentKind = preset.backend
        next.model = preset.model
        next.effort = DefaultBackend.effort(
            preset.effort, on: preset.backend, model: preset.model, models: models
        )
        if preset.backend.offersOutputStyle { next.outputStyle = preset.outputStyle }
        next.permissionMode = preset.permissionMode
        return next
    }

    func matches(_ preset: ModelPreset, models: [AgentKind: [AgentModel]] = [:]) -> Bool {
        guard agentKind == preset.backend,
              model == preset.model,
              effort == DefaultBackend.effort(
                  preset.effort, on: preset.backend, model: preset.model, models: models
              ),
              permissionMode == preset.permissionMode.nearest(on: agentKind)
        else { return false }
        guard offersOutputStyle else { return true }
        return OutputStyle.isDefault(outputStyle)
            ? OutputStyle.isDefault(preset.outputStyle)
            : outputStyle == preset.outputStyle
    }
}
