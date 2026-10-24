public enum SecondWindow: Sendable, Equatable, CaseIterable {
    case repoSettings
    case about
    case welcome
    case spend
    case settings

    public static func wanted(
        repoSettings: Bool,
        about: Bool,
        welcome: Bool,
        stage: CaptureStage,
        settings: Bool
    ) -> SecondWindow {
        if repoSettings { return .repoSettings }
        if about { return .about }
        if welcome { return .welcome }
        if stage.opensItsOwnWindow { return .spend }
        return .settings
    }

    public var identifier: String? {
        switch self {
        case .spend: "spend"
        case .settings: "settings"
        case .repoSettings: "repo-settings"
        case .about, .welcome: nil
        }
    }
}
