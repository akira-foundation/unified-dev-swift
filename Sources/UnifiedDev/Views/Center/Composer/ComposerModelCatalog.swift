import SwiftUI
import Core

struct ComposerModelSection: Identifiable, Equatable {
    var kind: AgentKind
    var options: [ComposerOption]

    var id: String { kind.rawValue }
    var title: String { kind.label }
}

@MainActor
@Observable
final class ComposerModelCatalog {
    static let shared = ComposerModelCatalog()

    private(set) var models: [AgentKind: [AgentModel]] = [:]
    private(set) var claudeModels = ClaudeModelMemory()
    private(set) var isLoading = false
    private(set) var lastFailure: String?

    private var sources: [AgentKind: AgentModelSource]
    private var store: Store?
    private var loadTask: Task<Void, Never>?
    private var saveTask: Task<Void, Never>?
    private var loadGeneration = UUID()

    init(sources: [AgentKind: AgentModelSource] = AgentModelSource.live()) {
        self.sources = sources
    }

    func configure(store: Store) {
        Task { await ComposerPlanningSupport.shared.refresh(from: store) }
        self.store = store
        sources = AgentModelSource.live(store: store)
        Task {
            let stored = await ClaudeModelMemory.load(from: store)
            claudeModels = stored.merging(claudeModels)
        }
        refresh()
    }

    @discardableResult
    func name(_ typed: String) -> ClaudeModelEntry.Outcome {
        let outcome = ClaudeModelEntry.accept(typed)
        if let id = outcome.id, claudeModels.remember(id) { saveClaudeModels() }
        return outcome
    }

    func forget(_ id: String) {
        guard claudeModels.forget(id) else { return }
        saveClaudeModels()
    }

    private func saveClaudeModels() {
        guard let store else { return }
        let memory = claudeModels
        let waiting = saveTask
        saveTask = Task {
            await waiting?.value
            try? await memory.save(to: store)
        }
    }

    func load() {
        guard loadTask == nil else { return }
        let needed = AgentKind.runnable.filter { sources[$0] != nil && (models[$0] ?? []).isEmpty }
        guard !needed.isEmpty else { return }
        isLoading = true
        let generation = loadGeneration
        loadTask = Task { [sources] in
            var failure: String?
            for kind in needed {
                guard generation == self.loadGeneration else { return }
                guard let source = sources[kind] else { continue }
                do {
                    let fetched = try await source.models()
                    guard generation == self.loadGeneration else { return }
                    self.models[kind] = fetched
                } catch {
                    if failure == nil { failure = error.readableMessage }
                }
            }
            guard generation == self.loadGeneration else { return }
            self.lastFailure = failure
            self.isLoading = false
            self.loadTask = nil
        }
    }

    func refresh() {
        loadTask?.cancel()
        loadGeneration = UUID()
        let generation = loadGeneration
        models = [:]
        isLoading = true
        loadTask = Task { [sources] in
            for source in sources.values { await source.invalidate() }
            guard generation == self.loadGeneration else { return }
            self.loadTask = nil
            self.isLoading = false
            load()
        }
    }

    func sections(includingCurrent current: String, on kind: AgentKind) -> [ComposerModelSection] {
        let owner = backend(ofModel: current, current: kind)
        return AgentKind.allCases.filter(\.canRunWorkspaces).compactMap { backend in
            let options = self.options(for: backend, including: backend == owner ? current : "")
            guard !options.isEmpty else { return nil }
            return ComposerModelSection(kind: backend, options: options)
        }
    }

    func options(for kind: AgentKind, including current: String = "") -> [ComposerOption] {
        if kind == .claudeCode {
            return ComposerOption.options(claudeModels.models(including: current))
        }
        let known = (models[kind] ?? []).filter { !$0.hidden }
            .map { ComposerOption(id: $0.id, label: $0.displayName) }
        return current.isEmpty ? known : ComposerOption.adding([current], to: known)
    }

    func backend(ofModel id: String, current: AgentKind) -> AgentKind {
        DefaultBackend.kind(
            ofModel: id,
            running: current,
            models: models
        )
    }

    func efforts(for kind: AgentKind, model: String) -> [ComposerOption] {
        guard kind != .claudeCode, let found = models[kind]?.first(where: { $0.id == model }) else {
            return ComposerOption.efforts
        }
        return found.supportedEfforts.map { ComposerOption(id: $0.id, label: $0.label) }
    }

    func resolvedEffort(_ wanted: String, for kind: AgentKind, model: String) -> String {
        DefaultBackend.effort(
            wanted,
            on: kind,
            model: model,
            models: models
        )
    }
}
