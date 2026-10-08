import Foundation

public enum Feedback {
    public enum Kind: Sendable, Equatable, CaseIterable {
        case report
        case prompt
    }

    public static let maxMessageCharacters = 5_000

    public static let maxPromptCharacters = 5_000

    public static let maxLogCharacters = 60_000

    public static func remainingMessage(count: Int, limit: Int) -> String? {
        guard count > limit - 500 else { return nil }
        guard count <= limit else {
            return "\(count) characters. Only the first \(limit) will be sent."
        }
        return "\(limit - count) characters left"
    }

    public enum InstallSource: String, Sendable, Equatable, CaseIterable, Codable {
        case release
        case local
        case localDirty = "local-dirty"

        public init(buildChannel: String?, masterCommit: String?, isDirty: Bool? = nil) {
            let commit = masterCommit ?? ""
            let isMasterBuild = !commit.isEmpty

            guard isMasterBuild || buildChannel != BuildIdentity.releaseChannel else {
                self = .release
                return
            }
            self = (isDirty == true || commit.hasSuffix(InstallSource.dirtySuffix)) ? .localDirty : .local
        }

        public static let dirtySuffix = "-dirty"

        public static let dirtyKey = "SourceDirty"
    }

    public enum Architecture: Sendable, Equatable, CaseIterable {
        case arm64
        case x86_64
        case unknown

        public init(isARM: Bool, isTranslated: Bool) {
            self = isARM && !isTranslated ? .arm64 : .x86_64
        }

        public var wireName: String? {
            switch self {
            case .arm64: "arm64"
            case .x86_64: "x86_64"
            case .unknown: nil
            }
        }
    }

    public static func wireName(_ mode: PermissionMode) -> String {
        switch mode {
        case .auto: "ask"
        case .acceptEdits: "accept-edits"
        case .autoReview: "approve-for-me"
        case .bypassPermissions: "full-access"
        case .plan: "plan"
        }
    }

    public enum FieldValue: Sendable, Equatable {
        case text(String)
        case number(Double)
        case boolean(Bool)
        case list([String])
    }

    public struct Field: Sendable, Equatable {
        public let name: String
        public let value: FieldValue

        public init(name: String, value: FieldValue) {
            self.name = name
            self.value = value
        }
    }

    public struct Environment: Sendable, Equatable {
        public let appVersion: String
        public let appBuild: String
        public let macOSVersion: String
        public let architecture: Architecture
        public let translated: Bool?
        public let installSource: InstallSource
        public let agent: String
        public let agentVersion: String
        public let availableAgents: [String]
        public let permissionMode: String
        public let theme: SystemReadings.Theme
        public let displayScale: Double
        public let locale: String

        public init(
            appVersion: String,
            appBuild: String,
            macOSVersion: String,
            architecture: Architecture,
            translated: Bool? = nil,
            installSource: InstallSource,
            agent: String,
            agentVersion: String = "",
            availableAgents: [String] = [],
            permissionMode: String,
            theme: SystemReadings.Theme,
            displayScale: Double,
            locale: String
        ) {
            self.appVersion = SystemReadings.checked(appVersion, SystemReadings.appVersionPattern, or: "")
            self.appBuild = SystemReadings.checked(appBuild, SystemReadings.appVersionPattern, or: "")
            self.macOSVersion = SystemReadings.checked(macOSVersion, SystemReadings.systemVersionPattern, or: "")
            self.architecture = architecture
            self.translated = architecture == .unknown ? nil : translated
            self.installSource = installSource
            self.agent = SystemReadings.checked(agent, Feedback.slugPattern, or: "")
            self.agentVersion = SystemReadings.checked(agentVersion, Feedback.agentVersionPattern, or: "")
            self.availableAgents = Array(
                availableAgents
                    .map { SystemReadings.checked($0, Feedback.slugPattern, or: "") }
                    .filter { !$0.isEmpty }
                    .sorted()
                    .prefix(Feedback.maxAgentSlugs)
            )
            self.permissionMode = SystemReadings.checked(permissionMode, Feedback.slugPattern, or: "")
            self.theme = theme
            self.displayScale = min(max(displayScale, 1), 4)
            self.locale = SystemReadings.checked(locale, Feedback.localePattern, or: "")
        }

        public var fields: [Field] {
            var found: [Field] = []

            func text(_ name: String, _ value: String) {
                guard !value.isEmpty else { return }
                found.append(Field(name: name, value: .text(value)))
            }

            text("app_version", appVersion)
            text("app_build", appBuild)
            text("macos_version", macOSVersion)
            text("architecture", architecture.wireName ?? "")
            if let translated {
                found.append(Field(name: "translated", value: .boolean(translated)))
            }
            text("install_source", installSource.rawValue)
            text("agent", agent)
            text("agent_version", agentVersion)
            if !availableAgents.isEmpty {
                found.append(Field(name: "available_agents", value: .list(availableAgents)))
            }
            text("permission_mode", permissionMode)
            text("theme", theme.rawValue)
            found.append(Field(name: "display_scale", value: .number(displayScale)))
            text("locale", locale)

            return found
        }
    }

    public static let maxAgentSlugs = 12

    public static let slugPattern = #"^[a-z][a-z0-9_-]{0,31}$"#

    public static let agentVersionPattern = #"^[0-9][A-Za-z0-9.+-]{0,31}$"#

    public static let localePattern = #"^[a-z]{2,8}(-[A-Za-z0-9]{2,8})?$"#

    public static let includesLogsKey = "feedback.includesLogs"

    public static let includesLogsByDefault = true

    public static func includesLogs(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: includesLogsKey) as? Bool ?? includesLogsByDefault
    }

    public static func rememberIncludesLogs(_ value: Bool, in defaults: UserDefaults = .standard) {
        defaults.set(value, forKey: includesLogsKey)
    }

    static func trimmed(_ text: String, to limit: Int) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count <= limit ? trimmed : String(trimmed.prefix(limit))
    }

    public static func canSend(message: String) -> Bool {
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func number(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%g", value)
    }

    public static let supportEmail = "support@akira-io.com"

    public enum Copy {
        public static let reportTitle = "Feedback"
        public static let reportBlurb =
            "Tell us what is not working, or what you wish Unified Dev did. You can also mail "
                + "\(Feedback.supportEmail) if you would rather write to a person."
        public static let reportPlaceholder =
            "Tell us about your experience, bugs you have found, or features you would like to see…"
        public static let reportSend = "Send feedback"
        public static let reportSent = "Thank you"

        public static let reportSentDetail = "Your report is now an issue on the repository."
        public static let promptSentDetail =
            "Your prompt is now an issue on the repository. If we run it, you will see it in "
                + "the changelog."
        public static let sentDismiss = "Done"
        public static let sentOpenIssue = "Open the issue"

        public static let logsToggle = "Include recent app logs (may include personal data)"
        public static let logsDetail =
            "The last half hour of what Unified Dev wrote to its own log, and nothing else. Paths, "
                + "addresses and anything that looks like a credential are taken out, and so are "
                + "your project, workspace and branch names. This is the text itself, not a "
                + "sample of it."
        public static let logsView = "View"
        public static let logsTitle = "What would be sent"

        public static let attachImages = "Attach images"

        public static let promptTitle = "Submit a prompt"
        public static let promptBlurb =
            "Prompt a coding agent to build what you want to see in Unified Dev. If we like your prompt, "
                + "we will run it and merge the result."
        public static let promptPlaceholder = "Describe what you would like to see built…"
        public static let promptSend = "Submit prompt"
        public static let promptSent = "Your prompt is in"

        public static let environmentNote =
            "This opens a public issue on \(AppRepository.slug) with your message, the app "
                + "version, your macOS version and how Unified Dev is set up here, and with the "
                + "recent logs if the box above is ticked. No file paths, project names or "
                + "account details."
    }
}
