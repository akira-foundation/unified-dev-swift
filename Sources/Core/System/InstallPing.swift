import Foundation

public enum InstallPing {
    public static let settingKey = "installPing.isEnabled"

    public static let tokenKey = "installPing.token"

    public static let firstSeenKey = "installPing.firstSeenAt"

    public static let lastSentKey = "installPing.lastSentAt"

    public static let isOnByDefault = true

    public static let defaultEndpoint = "https://unified-dev.akira-io.com/api/install-reports"

    public static let endpointVariable = "UD_PING_URL"

    public static func endpoint(
        buildChannel: String?,
        masterCommit: String?,
        environment: [String: String]
    ) -> URL? {
        let override = environment[endpointVariable]?.trimmingCharacters(in: .whitespacesAndNewlines)

        if let override, !override.isEmpty {
            return validEndpoint(override)
        }

        guard masterCommit?.isEmpty != false else { return nil }
        guard buildChannel == BuildIdentity.releaseChannel else { return nil }

        return validEndpoint(defaultEndpoint)
    }

    private static func validEndpoint(_ string: String) -> URL? {
        guard let url = URL(string: string),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http",
              let host = url.host, !host.isEmpty
        else { return nil }
        return url
    }

    public static let firstLaunchGrace: TimeInterval = 24 * 60 * 60

    public static let interval: TimeInterval = 20 * 60 * 60

    public static let recheckInterval: TimeInterval = 60 * 60

    public static let launchDelay: TimeInterval = 60

    public static func isDue(firstSeenAt: Date?, lastSentAt: Date?, now: Date) -> Bool {
        guard let firstSeenAt else { return false }
        guard now.timeIntervalSince(firstSeenAt) >= firstLaunchGrace else { return false }

        guard let lastSentAt else { return true }
        if lastSentAt > now { return true }
        return now.timeIntervalSince(lastSentAt) >= interval
    }

    @discardableResult
    public static func installToken(in defaults: UserDefaults = .standard) -> String {
        let stored = defaults.string(forKey: tokenKey)
        if let stored, isWellFormedToken(stored) { return stored }

        let fresh = newToken()
        defaults.set(fresh, forKey: tokenKey)
        return fresh
    }

    public static func newToken() -> String {
        UUID().uuidString
    }

    public static func isWellFormedToken(_ value: String) -> Bool {
        UUID(uuidString: value) != nil
    }

    public static func isEnabled(in defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: settingKey) as? Bool ?? isOnByDefault
    }

    @discardableResult
    public static func firstSeenAt(in defaults: UserDefaults = .standard, now: Date = Date()) -> Date {
        if let stored = defaults.object(forKey: firstSeenKey) as? Date, stored <= now {
            return stored
        }

        defaults.set(now, forKey: firstSeenKey)
        return now
    }

    public static func storedFirstSeenAt(in defaults: UserDefaults = .standard) -> Date? {
        defaults.object(forKey: firstSeenKey) as? Date
    }

    public static func lastSentAt(in defaults: UserDefaults = .standard) -> Date? {
        defaults.object(forKey: lastSentKey) as? Date
    }

    public static func recordSend(at date: Date, in defaults: UserDefaults = .standard) {
        defaults.set(date, forKey: lastSentKey)
    }

    public enum Theme: String, Sendable, Equatable, CaseIterable, Codable {
        case system
        case light
        case dark

        public static let defaultsKey = "appearance"

        public init(defaultsValue: String?) {
            self = Theme(rawValue: defaultsValue ?? "") ?? .system
        }

        public init(in defaults: UserDefaults = .standard) {
            self.init(defaultsValue: defaults.string(forKey: Theme.defaultsKey))
        }
    }

    public static func wireName(_ kind: AgentKind) -> String {
        switch kind {
        case .claudeCode: "claude"
        case .codex: "codex"
        case .grok: "grok"
        case .cursor: "cursor"
        case .openCode: "opencode"
        }
    }

    public static let noAgent = "none"

    public static func agentName(installed: [AgentKind]) -> String {
        let runnable = AgentKind.allCases.filter { $0.canRunWorkspaces && installed.contains($0) }
        guard !runnable.isEmpty else { return noAgent }
        return runnable.map(wireName).joined(separator: "_")
    }

    public struct Payload: Sendable, Equatable, Encodable {
        public let token: String

        public let appVersion: String

        public let macOSVersion: String

        public let agent: String

        public let theme: Theme
        public let appBuild: String?
        public let computerName: String?
        public let architecture: String?
        public let translated: Bool?
        public let screenWidth: Int?
        public let screenHeight: Int?
        public let displayScale: Double?
        public let displayCount: Int?
        public let memoryBucket: MemoryBucket?

        public init(
            token: String,
            appVersion: String,
            macOSVersion: String,
            agent: String,
            theme: Theme,
            appBuild: String? = nil,
            computerName: String? = nil,
            architecture: Feedback.Architecture = .unknown,
            translated: Bool? = nil,
            screenWidth: Double? = nil,
            screenHeight: Double? = nil,
            displayScale: Double? = nil,
            displayCount: Int? = nil,
            memoryBucket: MemoryBucket? = nil
        ) {
            self.token = InstallPing.matches(token, InstallPing.tokenPattern) ? token : InstallPing.newToken()
            self.appVersion = InstallPing.checked(appVersion, InstallPing.appVersionPattern, or: InstallPing.unknownVersion)
            self.macOSVersion = InstallPing.checked(macOSVersion, InstallPing.systemVersionPattern, or: InstallPing.unknownVersion)
            self.agent = InstallPing.checked(agent, InstallPing.namePattern, or: InstallPing.unknownName)
            self.theme = theme
            self.appBuild = appBuild.flatMap { InstallPing.matches($0, #"^[A-Za-z0-9.]{1,16}$"#) ? $0 : nil }
            self.computerName = InstallPing.checkedComputerName(computerName)
            self.architecture = architecture.wireName
            self.translated = architecture == .unknown ? nil : translated
            let width = InstallPing.roundedScreenDimension(screenWidth)
            let height = InstallPing.roundedScreenDimension(screenHeight)
            self.screenWidth = height == nil ? nil : width
            self.screenHeight = width == nil ? nil : height
            self.displayScale = displayScale.flatMap { [1.0, 2.0, 3.0, 4.0].contains($0) ? $0 : nil }
            self.displayCount = displayCount.flatMap { $0 > 0 ? min($0, 16) : nil }
            self.memoryBucket = memoryBucket
        }

        enum CodingKeys: String, CodingKey {
            case token
            case appVersion = "app_version"
            case macOSVersion = "macos_version"
            case agent
            case theme
            case appBuild = "app_build"
            case computerName = "computer_name"
            case architecture
            case translated
            case screenWidth = "screen_width"
            case screenHeight = "screen_height"
            case displayScale = "display_scale"
            case displayCount = "display_count"
            case memoryBucket = "memory_bucket"
        }
    }

    public static func checkedComputerName(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty, value.unicodeScalars.count <= 255,
              value.rangeOfCharacter(from: .controlCharacters) == nil
        else { return nil }
        return value
    }

    public enum MemoryBucket: String, Sendable, Equatable, Encodable, CaseIterable {
        case upTo8GiB = "up_to_8_gib"
        case upTo16GiB = "up_to_16_gib"
        case upTo32GiB = "up_to_32_gib"
        case upTo64GiB = "up_to_64_gib"
        case over64GiB = "over_64_gib"

        public init?(bytes: UInt64) {
            guard bytes > 0 else { return nil }
            let gib: UInt64 = 1_073_741_824
            switch bytes {
            case ...(UInt64(8) * gib): self = .upTo8GiB
            case ...(UInt64(16) * gib): self = .upTo16GiB
            case ...(UInt64(32) * gib): self = .upTo32GiB
            case ...(UInt64(64) * gib): self = .upTo64GiB
            default: self = .over64GiB
            }
        }
    }

    public static func roundedScreenDimension(_ points: Double?) -> Int? {
        guard let points, points.isFinite, (100...20_000).contains(points) else { return nil }
        return Int((points / 100).rounded()) * 100
    }

    public static let tokenPattern = #"^[A-Za-z0-9-]{16,64}$"#

    public static let appVersionPattern = #"^\d{1,4}(\.\d{1,4}){0,3}(-[A-Za-z0-9.]{1,16})?$"#

    public static let systemVersionPattern = #"^\d{1,3}(\.\d{1,3}){0,2}$"#

    public static let namePattern = #"^[a-z][a-z0-9_-]{0,31}$"#

    public static let unknownVersion = "0.0.0"

    public static let unknownName = "unknown"

    public static let maximumBodyBytes = 2_048

    static func matches(_ value: String, _ pattern: String) -> Bool {
        value.range(of: pattern, options: .regularExpression) != nil
    }

    static func checked(_ raw: String, _ pattern: String, or fallback: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return matches(trimmed, pattern) ? trimmed : fallback
    }

    public static func macOSVersion(major: Int, minor: Int, patch: Int) -> String {
        let clamped = [major, minor, patch].map { min(max($0, 0), 999) }
        return clamped.map(String.init).joined(separator: ".")
    }

    public static func body(_ payload: Payload) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(payload)
    }

    public static func request(to endpoint: URL, payload: Payload) throws -> URLRequest {
        var request = URLRequest(url: endpoint, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        request.httpMethod = "POST"
        request.httpBody = try body(payload)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Unified Dev/\(payload.appVersion)", forHTTPHeaderField: "User-Agent")
        request.httpShouldHandleCookies = false
        return request
    }

    public enum Outcome: Sendable, Equatable {
        case accepted

        case refused

        case throttled(retryAfter: TimeInterval?)

        case failed
    }

    public static func outcome(statusCode: Int, retryAfter: String? = nil, now: Date = Date()) -> Outcome {
        switch statusCode {
        case 200..<300: .accepted
        case 429: .throttled(retryAfter: retryAfterSeconds(retryAfter, now: now))
        case 400..<500: .refused
        default: .failed
        }
    }

    public static func closesTheDay(_ outcome: Outcome) -> Bool {
        switch outcome {
        case .accepted, .refused: true
        case .throttled, .failed: false
        }
    }

    public static func delay(after outcome: Outcome) -> TimeInterval {
        switch outcome {
        case .throttled(let retryAfter): max(recheckInterval, retryAfter ?? recheckInterval)
        case .accepted, .refused, .failed: recheckInterval
        }
    }

    public static func retryAfterSeconds(_ header: String?, now: Date = Date()) -> TimeInterval? {
        guard let header = header?.trimmingCharacters(in: .whitespacesAndNewlines), !header.isEmpty else {
            return nil
        }

        if let seconds = TimeInterval(header) { return max(0, seconds) }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        guard let date = formatter.date(from: header) else { return nil }
        return max(0, date.timeIntervalSince(now))
    }

    public static let settingTitle = "Share daily usage reports"

    public static let settingDetail =
        "Help improve Unified Dev by sharing a random install token, computer name, app version and build, macOS version, installed agents, theme, processor architecture, Rosetta status, rounded display dimensions, display scale and count, and memory range."

    public static let settingFooter =
        "Reports start a day after first launch and count installations. Your computer name may include your name and identify you. Display dimensions are rounded to 100 points and memory is grouped into broad ranges. Reports contain no account details, hardware identifiers, project paths or prompts. Feedback uses the same token, so an email you include with feedback can identify that installation."
}
