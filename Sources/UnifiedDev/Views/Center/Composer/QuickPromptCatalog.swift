import Foundation
import Observation
import Core

@MainActor
@Observable
final class QuickPromptCatalog {
    static let shared = QuickPromptCatalog()

    private(set) var prompts: [QuickPrompt] = []
    private(set) var isLoaded = false

    private var loading: Task<Void, Never>?

    private var watching: Task<Void, Never>?

    func load(from store: Store?) async {
        guard !isLoaded, let store else { return }
        if let loading {
            await loading.value
            return
        }
        let task = Task { @MainActor in
            let loaded = (try? await store.seedQuickPrompts()) ?? []
            prompts = loaded
            isLoaded = true
        }
        loading = task
        await task.value
        loading = nil
        watch(store)
    }

    private func watch(_ store: Store) {
        guard watching == nil else { return }
        watching = Task { [weak self] in
            for await _ in store.changes(of: [.quickPrompts]) {
                guard let self else { return }
                await self.reload(from: store)
            }
        }
    }

    func reload(from store: Store?) async {
        guard let store else { return }
        prompts = (try? await store.quickPrompts()) ?? []
        isLoaded = true
    }

    @discardableResult
    func add(_ fields: QuickPrompt.Fields, in store: Store?) async -> QuickPrompt? {
        guard let store else { return nil }
        let prompt = QuickPrompt(
            name: fields.name,
            symbol: fields.symbol,
            text: fields.text,
            sendsImmediately: fields.sendsImmediately,
            opensNewChat: fields.opensNewChat
        )
        guard let written = try? await store.insert(prompt) else { return nil }
        prompts.append(written)
        return written
    }

    @discardableResult
    func save(
        id: QuickPromptID, _ fields: QuickPrompt.Fields, in store: Store?
    ) async -> QuickPrompt? {
        guard let store else { return nil }
        let changed = try? await store.update(quickPromptID: id) { $0.fields = fields }
        guard let changed else { return nil }
        if let index = prompts.firstIndex(where: { $0.id == id }) {
            prompts[index] = changed
        }
        return changed
    }

    func delete(id: QuickPromptID, in store: Store?) async {
        guard let store else { return }
        try? await store.deleteQuickPrompt(id: id)
        prompts.removeAll { $0.id == id }
    }
}
