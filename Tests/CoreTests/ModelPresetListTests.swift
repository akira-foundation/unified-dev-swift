import Foundation
import Testing
@testable import Core

@Suite("The list of model presets", .tags(.persistence), .scratchDirectory)
struct ModelPresetListTests {
    static let opusHigh = ModelPreset(
        name: "Opus 5 High", model: "opus", effort: "high", backend: .claudeCode,
        permissionMode: .bypassPermissions
    )
    static let solLow = ModelPreset(
        name: "Sol Low", model: "gpt-5.6-sol", effort: "low", backend: .codex, permissionMode: .autoReview
    )
    static let sonnet = ModelPreset(
        name: "Sonnet", model: "sonnet", effort: "low", backend: .claudeCode, permissionMode: .plan
    )

    @Test("The first match in menu order wins")
    func firstMatchWins() {
        var twin = Self.opusHigh
        twin.id = .new()
        twin.name = "Twin"
        let list = ModelPresetList(presets: [Self.solLow, Self.opusHigh, twin])
        let controls = ComposerControls().applying(twin)
        #expect(list.matching(controls)?.name == "Opus 5 High")
        #expect(ModelPresetList(presets: [Self.solLow]).matching(controls) == nil)
    }

    @Test("Deleting the default clears it rather than promoting the next one")
    func deletingTheDefault() {
        var list = ModelPresetList(presets: [Self.opusHigh, Self.solLow])
        list.setDefault(Self.opusHigh.id)
        #expect(list.defaultPreset == Self.opusHigh)
        list.delete(id: Self.opusHigh.id)
        #expect(list.defaultID == nil)
        #expect(list.presets == [Self.solLow])
    }

    @Test("Deleting anything else leaves the default where it was")
    func deletingAnother() {
        var list = ModelPresetList(presets: [Self.opusHigh, Self.solLow])
        list.setDefault(Self.opusHigh.id)
        list.delete(id: Self.solLow.id)
        #expect(list.defaultID == Self.opusHigh.id)
    }

    @Test("Adding puts the preset at the end, keeping the others")
    func adding() {
        var list = ModelPresetList(presets: [Self.opusHigh])
        list.setDefault(Self.opusHigh.id)
        list.add(Self.solLow)
        #expect(list.presets.map(\.name) == ["Opus 5 High", "Sol Low"])
        #expect(list.defaultID == Self.opusHigh.id)
    }

    @Test("A default must be in the list")
    func defaultMustBeListed() {
        var list = ModelPresetList(presets: [Self.solLow])
        list.setDefault(Self.opusHigh.id)
        #expect(list.defaultID == nil)
        #expect(ModelPresetList(presets: [Self.solLow], defaultID: Self.opusHigh.id).defaultID == nil)
        list.setDefault(Self.solLow.id)
        list.setDefault(nil)
        #expect(list.defaultID == nil)
    }

    @Test("Updating keeps the preset's place in the list")
    func updateKeepsThePlace() {
        var list = ModelPresetList(presets: [Self.opusHigh, Self.solLow])
        var changed = Self.opusHigh
        changed.effort = "medium"
        list.update(changed)
        #expect(list.presets.map(\.id) == [Self.opusHigh.id, Self.solLow.id])
        #expect(list.presets.first?.effort == "medium")
    }

    @Test("Renaming trims the name and refuses a blank one")
    func renaming() {
        var list = ModelPresetList(presets: [Self.opusHigh])
        list.rename(id: Self.opusHigh.id, to: "  Deep  ")
        #expect(list.presets.first?.name == "Deep")
        list.rename(id: Self.opusHigh.id, to: "   ")
        #expect(list.presets.first?.name == "Deep")
    }

    @Test("Moving by offsets and by one place, clamped at the ends")
    func moving() {
        var list = ModelPresetList(presets: [Self.opusHigh, Self.solLow, Self.sonnet])
        list.move(fromOffsets: IndexSet(integer: 0), toOffset: 3)
        #expect(list.presets.map(\.name) == ["Sol Low", "Sonnet", "Opus 5 High"])
        list.move(fromOffsets: IndexSet(integer: 2), toOffset: 0)
        #expect(list.presets.map(\.name) == ["Opus 5 High", "Sol Low", "Sonnet"])
        list.move(fromOffsets: IndexSet([0, 2]), toOffset: 1)
        #expect(list.presets.map(\.name) == ["Opus 5 High", "Sonnet", "Sol Low"])
        list.move(fromOffsets: IndexSet([0, 1]), toOffset: 3)
        #expect(list.presets.map(\.name) == ["Sol Low", "Opus 5 High", "Sonnet"])
        list.move(fromOffsets: IndexSet(integer: 0), toOffset: 0)
        #expect(list.presets.map(\.name) == ["Sol Low", "Opus 5 High", "Sonnet"])
        list.move(fromOffsets: IndexSet([0, 1, 2]), toOffset: 0)
        #expect(list.presets.map(\.name) == ["Sol Low", "Opus 5 High", "Sonnet"])
        list.move(id: Self.opusHigh.id, by: 1)
        #expect(list.presets.map(\.name) == ["Sol Low", "Sonnet", "Opus 5 High"])
        list.move(id: Self.sonnet.id, by: -1)
        #expect(list.presets.map(\.name) == ["Sonnet", "Sol Low", "Opus 5 High"])
        list.move(id: Self.sonnet.id, by: -1)
        #expect(list.presets.map(\.name) == ["Sonnet", "Sol Low", "Opus 5 High"])
        list.move(id: Self.opusHigh.id, by: 1)
        #expect(list.presets.map(\.name) == ["Sonnet", "Sol Low", "Opus 5 High"])
    }

    @Test("A missing or unreadable value is an empty list")
    func unreadable() {
        #expect(ModelPresetList.decode(nil) == ModelPresetList())
        #expect(ModelPresetList.decode("not json") == ModelPresetList())
        #expect(ModelPresetList().encoded() == nil)
    }

    @Test("A stored preset with a mode its agent lacks is read back settled")
    func storedModeIsSettled() {
        let raw = """
        {"presets":[{"id":"x","name":"P","model":"gpt-5.5","effort":"low",\
        "backend":"codex","outputStyle":"default","permissionMode":"plan"}],"defaultID":null}
        """
        #expect(ModelPresetList.decode(raw).presets.first?.permissionMode == .auto)
    }

    @Test("Saved and loaded in order, with the default")
    func roundTrip() async throws {
        let store = try makeTestStore("model-preset-list-round-trip")
        var list = ModelPresetList(presets: [Self.solLow, Self.opusHigh])
        list.setDefault(Self.opusHigh.id)
        try await list.save(to: store)
        #expect(await ModelPresetList.load(from: store) == list)
    }

    @Test("Saving an empty list removes the stored value")
    func emptyClears() async throws {
        let store = try makeTestStore("model-preset-list-empty")
        try await ModelPresetList(presets: [Self.opusHigh]).save(to: store)
        try await ModelPresetList().save(to: store)
        let stored = try await store.setting(ModelPresetList.key)
        #expect(stored == nil)
    }
}
