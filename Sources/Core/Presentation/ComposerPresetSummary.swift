import Foundation

public struct ComposerPresetSummary: Equatable, Sendable {
    public let matched: ModelPreset?
    public let title: String
    public let isOneOff: Bool
    public let help: String
    public let accessibilityValue: String
    public let suggestedName: String

    public init(
        controls: ComposerControls,
        presets: ModelPresetList,
        modelLabel: String,
        effortLabel: String,
        models: [AgentKind: [AgentModel]] = [:]
    ) {
        let matched = presets.matching(controls, models: models)
        let permission = controls.permissionMode.label(on: controls.agentKind)
        let base = "\(modelLabel), \(effortLabel), \(permission)"
        self.matched = matched
        self.title = matched?.name ?? "\(modelLabel) \u{00B7} \(effortLabel)"
        self.isOneOff = matched == nil && !presets.presets.isEmpty
        self.help = matched.map { "Agent settings, preset \($0.name)" } ?? "Agent settings"
        self.accessibilityValue = matched.map { "\($0.name): \(base)" } ?? base
        self.suggestedName = "\(modelLabel) \(effortLabel)"
    }
}
