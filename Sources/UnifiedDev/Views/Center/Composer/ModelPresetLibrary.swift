import Foundation
import Observation
import Core

@MainActor
@Observable
final class ModelPresetLibrary {
    static let shared = ModelPresetLibrary()

    private(set) var list = ModelPresetList()
    private(set) var isLoaded = false
    private(set) var saveFailure: String?

    @ObservationIgnored private var saving: Task<Void, Never>?
    @ObservationIgnored private var loading: Task<Void, Never>?

    var presets: [ModelPreset] { list.presets }

    func load(from store: Store?) async {
        guard !isLoaded else { return }
        if let loading { return await loading.value }
        guard let store else { return }
        let task = Task {
            let read = await ModelPresetList.load(from: store)
            list = read
            isLoaded = true
        }
        loading = task
        await task.value
        loading = nil
    }

    func dismissSaveFailure() {
        saveFailure = nil
    }

    @discardableResult
    func add(_ preset: ModelPreset, in store: Store?) -> ModelPreset {
        change(in: store) { $0.add(preset) }
        return preset
    }

    func update(_ preset: ModelPreset, in store: Store?) {
        change(in: store) { $0.update(preset) }
    }

    func rename(id: ModelPresetID, to name: String, in store: Store?) {
        change(in: store) { $0.rename(id: id, to: name) }
    }

    func delete(id: ModelPresetID, in store: Store?) {
        change(in: store) { $0.delete(id: id) }
    }

    func setDefault(_ id: ModelPresetID?, in store: Store?) {
        change(in: store) { $0.setDefault(id) }
    }

    func move(fromOffsets source: IndexSet, toOffset destination: Int, in store: Store?) {
        change(in: store) { $0.move(fromOffsets: source, toOffset: destination) }
    }

    func move(id: ModelPresetID, by offset: Int, in store: Store?) {
        change(in: store) { $0.move(id: id, by: offset) }
    }

    private func change(in store: Store?, _ edit: (inout ModelPresetList) -> Void) {
        guard isLoaded, let store else { return }
        var next = list
        edit(&next)
        guard next != list else { return }
        list = next
        let pending = saving
        saving = Task {
            await pending?.value
            do {
                try await next.save(to: store)
                saveFailure = nil
            } catch {
                saveFailure = error.readableMessage
            }
        }
    }
}
