public enum SettingsWritePhase: Equatable, Sendable {
    case idle
    case pending
    case writing
    case wrote
    case failed(String)
}

public enum SettingsSaveLabel {
    public static func text(destination: String, phase: SettingsWritePhase) -> String {
        switch phase {
        case .idle: destination.isEmpty ? "" : "Saved to \(destination)"
        case .pending: "Unsaved changes"
        case .writing: "Saving"
        case .wrote: "Saved just now"
        case .failed(let reason): "Not saved: \(reason)"
        }
    }

    public static func isFailure(_ phase: SettingsWritePhase) -> Bool {
        guard case .failed = phase else { return false }
        return true
    }
}
