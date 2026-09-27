import Foundation

public struct ModelPreset: Identifiable, Codable, Equatable, Sendable {
    public var id: ModelPresetID
    public var name: String
    public var model: String
    public var effort: String
    public var backend: AgentKind
    public var outputStyle: String
    public var permissionMode: PermissionMode

    public init(
        id: ModelPresetID = .new(),
        name: String,
        model: String,
        effort: String,
        backend: AgentKind,
        outputStyle: String = OutputStyle.defaultName,
        permissionMode: PermissionMode
    ) {
        self.id = id
        self.name = name
        self.model = model
        self.effort = effort
        self.backend = backend
        self.outputStyle = outputStyle
        self.permissionMode = permissionMode.nearest(on: backend)
    }

    public init(name: String, controls: ComposerControls) {
        self.init(
            name: name,
            model: controls.model,
            effort: controls.effort,
            backend: controls.agentKind,
            outputStyle: controls.outputStyle,
            permissionMode: controls.permissionMode
        )
    }

    public static func cleanName(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
