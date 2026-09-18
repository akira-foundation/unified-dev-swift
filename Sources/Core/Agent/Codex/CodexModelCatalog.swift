import Foundation

public struct CodexModel: Sendable, Hashable, Identifiable {
    public let id: String
    public let displayName: String
    public let description: String
    public let isDefault: Bool
    public let hidden: Bool
    public let supportedEfforts: [CodexReasoningEffort]
    public let defaultEffort: String
    public let inputModalities: [String]
    public let supportsPersonality: Bool
    public let fastServiceTier: String?
    public let defaultServiceTier: String?

    public init(
        id: String,
        displayName: String,
        description: String = "",
        isDefault: Bool = false,
        hidden: Bool = false,
        supportedEfforts: [CodexReasoningEffort] = [],
        defaultEffort: String = "",
        inputModalities: [String] = [],
        supportsPersonality: Bool = false,
        fastServiceTier: String? = nil,
        defaultServiceTier: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.description = description
        self.isDefault = isDefault
        self.hidden = hidden
        self.supportedEfforts = supportedEfforts
        self.defaultEffort = defaultEffort
        self.inputModalities = inputModalities
        self.supportsPersonality = supportsPersonality
        self.fastServiceTier = fastServiceTier
        self.defaultServiceTier = defaultServiceTier
    }

    public var acceptsImages: Bool { inputModalities.contains("image") }

    public var effortIDs: [String] { supportedEfforts.map(\.id) }

    public var agentModel: AgentModel {
        AgentModel(
            id: id,
            displayName: displayName,
            isDefault: isDefault,
            hidden: hidden,
            supportedEfforts: supportedEfforts.map { AgentModelEffort(id: $0.id, label: $0.label) },
            defaultEffort: defaultEffort
        )
    }

    public func resolvedEffort(preferring wanted: String) -> String {
        agentModel.resolvedEffort(preferring: wanted)
    }

    static func decode(_ json: JSONValue) -> CodexModel? {
        guard let id = json["id"]?.stringValue else { return nil }
        let efforts = (json["supportedReasoningEfforts"]?.arrayValue ?? [])
            .compactMap(CodexReasoningEffort.decode)
        return CodexModel(
            id: id,
            displayName: json["displayName"]?.stringValue ?? id,
            description: json["description"]?.stringValue ?? "",
            isDefault: json["isDefault"]?.boolValue ?? false,
            hidden: json["hidden"]?.boolValue ?? false,
            supportedEfforts: efforts,
            defaultEffort: json["defaultReasoningEffort"]?.stringValue ?? "",
            inputModalities: (json["inputModalities"] ?? .null).stringArray,
            supportsPersonality: json["supportsPersonality"]?.boolValue ?? false,
            fastServiceTier: (json["serviceTiers"]?.arrayValue ?? []).first {
                ["fast", "priority"].contains($0["id"]?.stringValue ?? "")
            }?["id"]?.stringValue
                ?? ((json["additionalSpeedTiers"] ?? .null).stringArray.contains("fast") ? "priority" : nil),
            defaultServiceTier: json["defaultServiceTier"]?.stringValue
        )
    }

    static func decodeList(_ json: JSONValue) -> [CodexModel] {
        (json["data"]?.arrayValue ?? []).compactMap(CodexModel.decode)
    }
}

public struct CodexReasoningEffort: Sendable, Hashable, Identifiable {
    public let id: String
    public let description: String

    public init(id: String, description: String = "") {
        self.id = id
        self.description = description
    }

    public var label: String {
        switch id {
        case "xhigh": "Extra high"
        default: id.capitalizedFirst
        }
    }

    static func decode(_ json: JSONValue) -> CodexReasoningEffort? {
        guard let id = json["reasoningEffort"]?.stringValue else { return nil }
        return CodexReasoningEffort(id: id, description: json["description"]?.stringValue ?? "")
    }
}

public actor CodexModelCatalog {
    public static let freshness = AgentModelCache<CodexModel>.freshness

    private let cache: AgentModelCache<CodexModel>

    public var fetchCount: Int { get async { await cache.fetchCount } }

    public init(
        fetch: @escaping @Sendable () async throws -> [CodexModel],
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        cache = AgentModelCache(fetch: { Self.sorted(try await fetch()) }, now: now)
    }

    public static func live(
        cwd: String = AgentScratchDirectory.current(),
        codexHome: String? = nil,
        makeProcess: @escaping @Sendable (AgentLaunch) -> any AgentProcessing = CodexClient.spawn
    ) -> CodexModelCatalog {
        CodexModelCatalog(fetch: {
            await LoginShellPath.ready()
            let client = CodexClient(
                configuration: CodexClient.Configuration(cwd: cwd, codexHome: codexHome),
                makeProcess: makeProcess
            )
            defer { Task { await client.stop() } }
            try await client.start()
            return try await client.listModels()
        })
    }

    public func models() async throws -> [CodexModel] {
        try await cache.models()
    }

    public func pickerModels() async throws -> [CodexModel] {
        try await models().filter { !$0.hidden }
    }

    public func efforts(for modelID: String) async throws -> [CodexReasoningEffort] {
        try await models().first { $0.id == modelID }?.supportedEfforts ?? []
    }

    public func invalidate() async {
        await cache.invalidate()
    }

    public var lastKnown: [CodexModel] { get async { await cache.lastKnown } }

    static func sorted(_ models: [CodexModel]) -> [CodexModel] {
        CodexModelRank.ordered(models)
    }
}
