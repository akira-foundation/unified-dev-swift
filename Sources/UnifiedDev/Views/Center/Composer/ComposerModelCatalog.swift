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
    private(set) var isLoading = false
    private(set) var lastFailure: String?

    private var sources: [AgentKind: AgentModelSource]
    private var loadTask: Task<Void, Never>?
    private var loadGeneration = UUID()

    init(sources: [AgentKind: AgentModelSource] = AgentModelSource.live()) {
        self.sources = sources
    }

    func configure(store: Store) {
        Task { await ComposerPlanningSupport.shared.refresh(from: store) }
        sources = AgentModelSource.live(store: store)
        refresh()
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
            var options = self.options(for: backend)
            if backend == owner {
                options = ComposerOption.adding([current], to: options)
            }
            if backend == .claudeCode {
                options = ComposerOption.ranked(options)
            }
            guard !options.isEmpty else { return nil }
            return ComposerModelSection(kind: backend, options: options)
        }
    }

    func options(for kind: AgentKind) -> [ComposerOption] {
        if kind == .claudeCode { return ComposerOption.models }
        return (models[kind] ?? []).filter { !$0.hidden }
            .map { ComposerOption(id: $0.id, label: $0.displayName) }
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
