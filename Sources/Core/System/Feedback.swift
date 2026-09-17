import Foundation

public enum Feedback {
    public static let reportEndpoint = "https://unified-dev.akira-io.com/api/feedback-submissions"
    public static let promptEndpoint = "https://unified-dev.akira-io.com/api/prompt-submissions"

    public static let reportEndpointVariable = "UD_FEEDBACK_URL"
    public static let promptEndpointVariable = "UD_PROMPT_URL"

    public enum Kind: Sendable, Equatable, CaseIterable {
        case report
        case prompt

        var endpoint: String {
            switch self {
            case .report: Feedback.reportEndpoint
            case .prompt: Feedback.promptEndpoint
            }
        }

        var variable: String {
            switch self {
            case .report: Feedback.reportEndpointVariable
            case .prompt: Feedback.promptEndpointVariable
            }
        }
    }

    public static func endpoint(_ kind: Kind, environment: [String: String]) -> URL? {
        let override = environment[kind.variable]?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let override, !override.isEmpty { return validEndpoint(override) }
        return validEndpoint(kind.endpoint)
    }

    private static func validEndpoint(_ string: String) -> URL? {
        guard let url = URL(string: string),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http",
              let host = url.host, !host.isEmpty
        else { return nil }
        return url
    }

    public static let maxMessageCharacters = 5_000
    public static let maxPromptCharacters = 5_000

    public static let maxLogCharacters = 60_000

    public static let maxNameCharacters = 60

    public static let maxEmailCharacters = 254

    public static let maxImages = 5
    public static let maxImageBytes = 8 * 1024 * 1024

    public static let maxTotalImageBytes = 12 * 1024 * 1024

    public static let maximumBodyBytes = 14_680_064

    public static func tooLargeMessage(name: String, bytes: Int) -> String {
        "\(name) is \(size(bytes)), and one image can be \(size(maxImageBytes)) at most. "
            + "Scale it down, or send a crop of the part that matters."
    }

    public static func tooManyMessage() -> String {
        "That is more than \(maxImages) images, which is as many as one report carries."
    }

    public static func tooMuchMessage() -> String {
        "That is more than \(size(maxTotalImageBytes)) of images all together, which is as much "
            + "as one report carries. Take one off, or send a smaller one."
    }

    public static func notAnImageMessage(name: String) -> String {
        "\(name) is not an image Unified Dev can send. PNG, JPEG, GIF, WebP and HEIC go; PDFs and SVGs "
            + "do not."
    }

    public static func remainingMessage(count: Int, limit: Int) -> String? {
        guard count > limit - 500 else { return nil }
        guard count <= limit else {
            return "\(count) characters. Only the first \(limit) will be sent."
        }
        return "\(limit - count) characters left"
    }

    static func size(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .binary)
    }

    public enum InstallSource: String, Sendable, Equatable, CaseIterable, Codable {
        case release
        case local
        case localDirty = "local-dirty"

        public init(buildChannel: String?, masterCommit: String?, isDirty: Bool? = nil) {
            let commit = masterCommit ?? ""
            let isMasterBuild = !commit.isEmpty

            guard isMasterBuild || buildChannel != InstallPing.releaseChannel else {
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
            if isTranslated {
                self = .x86_64
            } else if isARM {
                self = .arm64
            } else {
                self = .x86_64
            }
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

    public struct Environment: Sendable, Equatable, Encodable {
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
        public let theme: InstallPing.Theme
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
            theme: InstallPing.Theme,
            displayScale: Double,
            locale: String
        ) {
            self.appVersion = InstallPing.checked(appVersion, InstallPing.appVersionPattern, or: "")
            self.appBuild = InstallPing.checked(appBuild, InstallPing.appVersionPattern, or: "")
            self.macOSVersion = InstallPing.checked(macOSVersion, InstallPing.systemVersionPattern, or: "")
            self.architecture = architecture
            self.translated = architecture == .unknown ? nil : translated
            self.installSource = installSource
            self.agent = InstallPing.checked(agent, Feedback.slugPattern, or: "")
            self.agentVersion = InstallPing.checked(agentVersion, Feedback.agentVersionPattern, or: "")
            self.availableAgents = Array(
                availableAgents
                    .map { InstallPing.checked($0, Feedback.slugPattern, or: "") }
                    .filter { !$0.isEmpty }
                    .sorted()
                    .prefix(Feedback.maxAgentSlugs)
            )
            self.permissionMode = InstallPing.checked(permissionMode, Feedback.slugPattern, or: "")
            self.theme = theme
            self.displayScale = min(max(displayScale, 1), 4)
            self.locale = InstallPing.checked(locale, Feedback.localePattern, or: "")
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

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: WireKey.self)
            for field in fields {
                let key = WireKey(field.name)
                switch field.value {
                case .text(let value): try container.encode(value, forKey: key)
                case .number(let value): try container.encode(value, forKey: key)
                case .boolean(let value): try container.encode(value, forKey: key)
                case .list(let value): try container.encode(value, forKey: key)
                }
            }
        }
    }

    public static let maxAgentSlugs = 12

    struct WireKey: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }

        init(_ stringValue: String) { self.stringValue = stringValue }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    public static let slugPattern = #"^[a-z][a-z0-9_-]{0,31}$"#

    public static let agentVersionPattern = #"^[0-9][A-Za-z0-9.+-]{0,31}$"#

    public static let localePattern = #"^[a-z]{2,8}(-[A-Za-z0-9]{2,8})?$"#

    public static let namePattern = #"^[\p{L}\p{N} ._'-]+$"#

    public static func normalisedName(_ raw: String) -> String {
        var name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.hasPrefix("@") { name.removeFirst() }
        return String(name.prefix(maxNameCharacters)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func isAcceptableName(_ raw: String) -> Bool {
        let name = normalisedName(raw)
        return name.isEmpty || InstallPing.matches(name, namePattern)
    }

    public static let nameProblem =
        "A name or a handle, please: letters, numbers, spaces, and . _ ' -. There is a field of "
            + "its own for your email below."

    public static let emailPattern = #"^[^@\s]+@[^@\s]+\.[^@\s]+$"#

    public static func normalisedEmail(_ raw: String) -> String {
        let email = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(email.prefix(maxEmailCharacters))
    }

    public static func isAcceptableEmail(_ raw: String) -> Bool {
        let email = normalisedEmail(raw)
        return email.isEmpty || matchesEmail(email)
    }

    static func sendableEmail(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let email = normalisedEmail(raw)
        return email.isEmpty || !matchesEmail(email) ? nil : email
    }

    private static func matchesEmail(_ email: String) -> Bool {
        InstallPing.matches(email, emailPattern)
    }

    public static let emailProblem = "That does not look like an email address."

    public enum SheetField: Sendable, Hashable {
        case name
        case email
    }

    public struct SheetProblems: Sendable, Equatable {
        public let name: String?
        public let email: String?

        public var isEmpty: Bool { name == nil && email == nil }

        public var firstField: SheetField? {
            if name != nil { return .name }
            if email != nil { return .email }
            return nil
        }

        public func message(for field: SheetField) -> String? {
            switch field {
            case .name: name
            case .email: email
            }
        }
    }

    public static func sheetProblems(
        name: String? = nil, email: String, afterSendAttempt: Bool
    ) -> SheetProblems {
        guard afterSendAttempt else { return SheetProblems(name: nil, email: nil) }
        return SheetProblems(
            name: name.flatMap { isAcceptableName($0) ? nil : nameProblem },
            email: isAcceptableEmail(email) ? nil : emailProblem
        )
    }

    public static let includesLogsKey = "feedback.includesLogs"
    public static let includesLogsByDefault = true

    public static func includesLogs(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: includesLogsKey) as? Bool ?? includesLogsByDefault
    }

    public static func rememberIncludesLogs(_ value: Bool, in defaults: UserDefaults = .standard) {
        defaults.set(value, forKey: includesLogsKey)
    }

    public struct Image: Sendable, Equatable {
        public let contentType: String
        public let data: Data

        public var filename: String { "attachment.\(Feedback.fileExtension(for: contentType))" }

        public init(contentType: String, data: Data) {
            self.contentType = Feedback.sniffedContentType(data) ?? Feedback.checkedContentType(contentType)
            self.data = data
        }
    }

    public static let imageContentTypes = [
        "image/png", "image/jpeg", "image/gif", "image/webp", "image/heic", "image/heif",
    ]

    static func checkedContentType(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return imageContentTypes.contains(trimmed) ? trimmed : "image/png"
    }

    public static func fileExtension(for contentType: String) -> String {
        switch contentType {
        case "image/png": "png"
        case "image/jpeg": "jpg"
        case "image/gif": "gif"
        case "image/webp": "webp"
        case "image/heic": "heic"
        case "image/heif": "heif"
        default: "png"
        }
    }

    public static func sniffedContentType(_ data: Data) -> String? {
        func starts(with bytes: [UInt8], at offset: Int = 0) -> Bool {
            guard data.count >= offset + bytes.count else { return false }
            let start = data.index(data.startIndex, offsetBy: offset)
            return Array(data[start..<data.index(start, offsetBy: bytes.count)]) == bytes
        }

        func ascii(at offset: Int, length: Int) -> String? {
            guard data.count >= offset + length else { return nil }
            let start = data.index(data.startIndex, offsetBy: offset)
            return String(bytes: data[start..<data.index(start, offsetBy: length)], encoding: .ascii)
        }

        if starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) { return "image/png" }
        if starts(with: [0xFF, 0xD8, 0xFF]) { return "image/jpeg" }
        if ascii(at: 0, length: 6) == "GIF87a" || ascii(at: 0, length: 6) == "GIF89a" { return "image/gif" }
        if ascii(at: 0, length: 4) == "RIFF", ascii(at: 8, length: 4) == "WEBP" { return "image/webp" }

        if ascii(at: 4, length: 4) == "ftyp", let brand = ascii(at: 8, length: 4) {
            if ["heic", "heix", "heim", "heis", "hevc", "hevx"].contains(brand) { return "image/heic" }
            if ["mif1", "msf1", "heif"].contains(brand) { return "image/heif" }
        }

        return nil
    }

    public struct Report: Sendable, Equatable, Encodable {
        public let message: String
        public let email: String?
        public let logs: String?
        public let images: [Image]
        public let token: String?
        public let environment: Environment

        public init(
            message: String,
            email: String?,
            logs: String?,
            images: [Image],
            token: String?,
            environment: Environment
        ) {
            self.message = Feedback.trimmed(message, to: Feedback.maxMessageCharacters)
            self.email = Feedback.sendableEmail(email)
            self.logs = logs.map { Feedback.trimmed($0, to: Feedback.maxLogCharacters) }
            self.images = Array(images.prefix(Feedback.maxImages))
            self.token = token.flatMap { InstallPing.matches($0, InstallPing.tokenPattern) ? $0 : nil }
            self.environment = environment
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: WireKey.self)
            try container.encode(message, forKey: WireKey("message"))
            try container.encodeIfPresent(email, forKey: WireKey("email"))
            try container.encodeIfPresent(logs, forKey: WireKey("logs"))
            try container.encodeIfPresent(token, forKey: WireKey("token"))
            try container.encode(environment, forKey: WireKey("environment"))
        }
    }

    public struct PromptSubmission: Sendable, Equatable, Encodable {
        public let prompt: String
        public let name: String?
        public let email: String?
        public let token: String?
        public let environment: Environment

        public init(prompt: String, name: String?, email: String?, token: String?, environment: Environment) {
            self.prompt = Feedback.trimmed(prompt, to: Feedback.maxPromptCharacters)
            let cleaned = name.map(Feedback.normalisedName) ?? ""
            self.name = cleaned.isEmpty || !InstallPing.matches(cleaned, Feedback.namePattern) ? nil : cleaned
            self.email = Feedback.sendableEmail(email)
            self.token = token.flatMap { InstallPing.matches($0, InstallPing.tokenPattern) ? $0 : nil }
            self.environment = environment
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: WireKey.self)
            try container.encode(prompt, forKey: WireKey("prompt"))
            try container.encodeIfPresent(name, forKey: WireKey("name"))
            try container.encodeIfPresent(email, forKey: WireKey("email"))
            try container.encodeIfPresent(token, forKey: WireKey("token"))
            try container.encode(environment, forKey: WireKey("environment"))
        }
    }

    static func trimmed(_ text: String, to limit: Int) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count <= limit ? trimmed : String(trimmed.prefix(limit))
    }

    public static func canSend(message: String) -> Bool {
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public struct Body: Sendable, Equatable {
        public let contentType: String
        public let data: Data

        public init(contentType: String, data: Data) {
            self.contentType = contentType
            self.data = data
        }
    }

    public static func body(for report: Report, boundary: String = newBoundary()) throws -> Body {
        guard !report.images.isEmpty else {
            return Body(contentType: "application/json", data: try json(report))
        }

        var parts: [MultipartPart] = [.text(name: "message", value: report.message)]
        if let logs = report.logs { parts.append(.text(name: "logs", value: logs)) }
        if let token = report.token { parts.append(.text(name: "token", value: token)) }
        parts += environmentParts(report.environment)
        parts += report.images.map {
            .file(name: "attachments[]", filename: $0.filename, contentType: $0.contentType, data: $0.data)
        }

        return Body(
            contentType: "multipart/form-data; boundary=\(boundary)",
            data: multipart(parts, boundary: boundary)
        )
    }

    public static func body(for submission: PromptSubmission) throws -> Body {
        Body(contentType: "application/json", data: try json(submission))
    }

    static func json(_ value: some Encodable) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }

    static func environmentParts(_ environment: Environment) -> [MultipartPart] {
        environment.fields.flatMap { field -> [MultipartPart] in
            switch field.value {
            case .text(let value):
                [.text(name: "environment[\(field.name)]", value: value)]
            case .number(let value):
                [.text(name: "environment[\(field.name)]", value: number(value))]
            case .boolean(let value):
                [.text(name: "environment[\(field.name)]", value: value ? "1" : "0")]
            case .list(let values):
                values.map { .text(name: "environment[\(field.name)][]", value: $0) }
            }
        }
    }

    static func number(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%g", value)
    }

    public enum MultipartPart: Sendable, Equatable {
        case text(name: String, value: String)
        case file(name: String, filename: String, contentType: String, data: Data)
    }

    public static func newBoundary() -> String {
        "FormBoundary\(UUID().uuidString)"
    }

    static func multipart(_ parts: [MultipartPart], boundary: String) -> Data {
        var body = Data()

        func append(_ string: String) {
            body.append(Data(string.utf8))
        }

        for part in parts {
            append("--\(boundary)\r\n")
            switch part {
            case .text(let name, let value):
                append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
                append(value)
                append("\r\n")
            case .file(let name, let filename, let contentType, let data):
                append(
                    "Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n"
                )
                append("Content-Type: \(contentType)\r\n\r\n")
                body.append(data)
                append("\r\n")
            }
        }
        append("--\(boundary)--\r\n")

        return body
    }

    public static func request(to endpoint: URL, body: Body, appVersion: String) -> URLRequest {
        var request = URLRequest(url: endpoint, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 60)
        request.httpMethod = "POST"
        request.httpBody = body.data
        request.setValue(body.contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(
            "Unified Dev/\(appVersion.isEmpty ? InstallPing.unknownVersion : appVersion)",
            forHTTPHeaderField: "User-Agent"
        )
        request.httpShouldHandleCookies = false
        return request
    }

    public enum Outcome: Sendable, Equatable {
        case sent
        case refused
        case throttled(retryAfter: TimeInterval?)
        case unreachable
    }

    public struct Result: Sendable, Equatable {
        public let outcome: Outcome
        public let reference: String?

        public init(outcome: Outcome, reference: String? = nil) {
            self.outcome = outcome
            self.reference = reference
        }

        public var isSent: Bool { outcome == .sent }
    }

    public static let referencePattern = #"^[0-9A-HJKMNP-TV-Z]{26}$"#

    public static func reference(in data: Data) -> String? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let raw = root["reference"] as? String
        else { return nil }

        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return InstallPing.matches(trimmed, referencePattern) ? trimmed : nil
    }

    public static func outcome(statusCode: Int, retryAfter: String? = nil, now: Date = Date()) -> Outcome {
        switch statusCode {
        case 200..<300: .sent
        case 429: .throttled(retryAfter: InstallPing.retryAfterSeconds(retryAfter, now: now))
        case 400..<500: .refused
        default: .unreachable
        }
    }

    public static func failureMessage(_ outcome: Outcome) -> String? {
        switch outcome {
        case .sent:
            nil
        case .refused:
            "The server would not take that. Nothing has been lost, and mailing \(supportEmail) "
                + "will reach the same person."
        case .throttled(let retryAfter):
            "That is a lot of reports at once. Try again \(waitPhrase(retryAfter)). Your text is still here."
        case .unreachable:
            "Unified Dev could not reach the server. Your text is still here, so you can try again in a "
                + "moment, or mail \(supportEmail)."
        }
    }

    static func waitPhrase(_ retryAfter: TimeInterval?) -> String {
        guard let retryAfter, retryAfter > 0 else { return "in a minute" }
        let minutes = Int((retryAfter / 60).rounded(.up))
        return minutes <= 1 ? "in a minute" : "in \(minutes) minutes"
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

        public static let reportSentDetail =
            "Your feedback is with us. We read everything that comes in, and if you left an "
                + "address we will write back."
        public static let promptSentDetail =
            "If we run it you will see it in the changelog, and if you left an address we will "
                + "tell you when it ships."
        public static let sentDismiss = "Done"

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
        public static let promptName = "Your name (if we use your prompt, we will credit you in the changelog)"
        public static let promptNamePlaceholder = "A name or a handle, not an email address"

        public static let reportEmail = "Your email (optional, so we can reply)"
        public static let promptEmail = "Your email (optional, so we can tell you when it ships)"
        public static let emailPlaceholder = "you@example.com"
        public static let promptSend = "Submit prompt"
        public static let promptSent = "Your prompt is in"

        public static let environmentNote =
            "Unified Dev attaches its version, your macOS version and how it is set up here. No file "
                + "paths, project names or account details."
    }
}
