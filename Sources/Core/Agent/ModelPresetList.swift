import Foundation

public struct ModelPresetList: Codable, Equatable, Sendable {
    public static let key = "defaults.modelPresets"

    public private(set) var presets: [ModelPreset]
    public private(set) var defaultID: ModelPresetID?

    public init(presets: [ModelPreset] = [], defaultID: ModelPresetID? = nil) {
        self.presets = presets
        self.defaultID = defaultID.flatMap { id in presets.contains { $0.id == id } ? id : nil }
    }

    public var defaultPreset: ModelPreset? {
        defaultID.flatMap(preset(id:))
    }

    public func preset(id: ModelPresetID) -> ModelPreset? {
        presets.first { $0.id == id }
    }

    public func matching(
        _ controls: ComposerControls,
        models: [AgentKind: [AgentModel]] = [:]
    ) -> ModelPreset? {
        presets.first { controls.matches($0, models: models) }
    }

    public mutating func add(_ preset: ModelPreset) {
        presets.append(preset)
    }

    public mutating func update(_ preset: ModelPreset) {
        guard let index = presets.firstIndex(where: { $0.id == preset.id }) else { return }
        presets[index] = preset
    }

    public mutating func rename(id: ModelPresetID, to name: String) {
        guard let name = ModelPreset.cleanName(name),
              let index = presets.firstIndex(where: { $0.id == id })
        else { return }
        presets[index].name = name
    }

    public mutating func delete(id: ModelPresetID) {
        presets.removeAll { $0.id == id }
        if defaultID == id { defaultID = nil }
    }

    public mutating func setDefault(_ id: ModelPresetID?) {
        guard let id else {
            defaultID = nil
            return
        }
        guard preset(id: id) != nil else { return }
        defaultID = id
    }

    public mutating func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        let moving = source.sorted().filter { presets.indices.contains($0) }
        guard !moving.isEmpty else { return }
        let items = moving.map { presets[$0] }
        let before = moving.filter { $0 < destination }.count
        for index in moving.reversed() { presets.remove(at: index) }
        let target = min(max(destination - before, 0), presets.count)
        presets.insert(contentsOf: items, at: target)
    }

    public mutating func move(id: ModelPresetID, by offset: Int) {
        guard let index = presets.firstIndex(where: { $0.id == id }) else { return }
        let target = min(max(index + offset, 0), presets.count - 1)
        guard target != index else { return }
        let preset = presets.remove(at: index)
        presets.insert(preset, at: target)
    }

    public static func decode(_ raw: String?) -> ModelPresetList {
        guard let raw, let data = raw.data(using: .utf8),
              let list = try? JSONDecoder().decode(ModelPresetList.self, from: data)
        else { return ModelPresetList() }
        return ModelPresetList(presets: list.presets.map(normalised), defaultID: list.defaultID)
    }

    private static func normalised(_ preset: ModelPreset) -> ModelPreset {
        ModelPreset(
            id: preset.id,
            name: preset.name,
            model: preset.model,
            effort: preset.effort,
            backend: preset.backend,
            outputStyle: preset.outputStyle,
            permissionMode: preset.permissionMode
        )
    }

    public func encoded() -> String? {
        guard !presets.isEmpty, let data = try? JSONEncoder().encode(self) else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    public static func load(from store: Store) async -> ModelPresetList {
        decode(try? await store.setting(key))
    }

    public func save(to store: Store) async throws {
        try await store.setSetting(Self.key, encoded())
    }
}
