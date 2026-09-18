import SwiftUI
import AppKit
import Core

@MainActor
@Observable
final class RepoSettingsModel {
    let repo: Repo

    private(set) var loaded = RepoSettings()
    private(set) var isLoaded = false

    private(set) var instructionFiles: [ProjectInstructions.Subject: String] = [:]

    var draft = RepoSettingsDraft() {
        didSet { scheduleWrite() }
    }

    private(set) var phase: SettingsWritePhase = .idle

    private var writeTask: Task<Void, Never>?
    private var isApplying = false

    private(set) var plan = FilesToCopyPlan()
    private(set) var isResolving = false

    private(set) var hasExternalChange = false
    private(set) var saveError: String?
    private(set) var savedPaths: [String] = []

    private var resolveTask: Task<Void, Never>?

    init(repo: Repo) {
        self.repo = repo
    }

    func load() async {
        let path = repo.path
        let settings = await Task.detached { SettingsLoader.load(repo: path) }.value
        instructionFiles = await Task.detached { ProjectInstructions.files(in: path) }.value
        apply(settings)
        isLoaded = true
        scheduleResolve(immediately: true)
    }

    func refresh() async {
        guard isLoaded else { return }
        let path = repo.path
        let settings = await Task.detached { SettingsLoader.load(repo: path) }.value
        instructionFiles = await Task.detached { ProjectInstructions.files(in: path) }.value
        guard settings != loaded else {
            scheduleResolve()
            return
        }
        if isDirty {
            loaded = settings
            hasExternalChange = true
        } else {
            apply(settings)
        }
        scheduleResolve()
    }

    private func apply(_ settings: RepoSettings) {
        isApplying = true
        loaded = settings
        hasExternalChange = false
        draft = RepoSettingsDraft(settings)
        isApplying = false
        writeTask?.cancel()
        phase = .idle
    }

    private func scheduleWrite() {
        guard !isApplying, isLoaded else { return }
        writeTask?.cancel()
        guard isDirty else {
            phase = .idle
            return
        }
        phase = .pending
        writeTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            await self?.writeNow()
        }
    }

    func writeNow() async {
        writeTask?.cancel()
        guard isDirty else { return }
        phase = .writing
        let written = await save()
        guard written else {
            phase = .failed(saveError ?? "the settings file could not be written")
            return
        }
        phase = .wrote
        writeTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, let self, self.phase == .wrote else { return }
            self.phase = .idle
        }
    }

    func revert() {
        apply(loaded)
        saveError = nil
        savedPaths = []
        scheduleResolve(immediately: true)
    }

    var globs: [String] { draft.globs }

    func scheduleResolve(immediately: Bool = false) {
        resolveTask?.cancel()
        let patterns = draft.globs
        let path = repo.path
        isResolving = true
        resolveTask = Task { [weak self] in
            if !immediately {
                try? await Task.sleep(for: .milliseconds(250))
                if Task.isCancelled { return }
            }
            let resolved = await Task.detached {
                FilesToCopyResolver.resolve(patterns: patterns, in: path)
            }.value
            guard !Task.isCancelled else { return }
            self?.plan = resolved
            self?.isResolving = false
        }
    }

    var edits: [SettingsEdit] { draft.edits(comparedTo: loaded) }

    var isDirty: Bool { !edits.isEmpty }

    func destination(for key: SettingsKey) -> String {
        SettingsWriter.destination(for: key, in: loaded, repo: repo.path)
    }

    func scriptFile(for location: ScriptLocation, script: String) -> String? {
        SettingsWriter.scriptFile(for: location, script: script, in: loaded, repo: repo.path)
    }

    func missingScriptFile(for location: ScriptLocation) -> String? {
        guard let file = loaded.scriptFiles[location], file.isMissing else { return nil }
        return file.path
    }

    var pendingDestinations: [String] {
        Array(Set(edits.map { destination(for: $0.key) })).sorted()
    }

    func save() async -> Bool {
        let pending = edits
        guard !pending.isEmpty else { return false }
        let path = repo.path
        let settings = loaded

        do {
            let written = try await Task.detached {
                try SettingsWriter.write(pending, repo: path, settings: settings)
            }.value
            savedPaths = written
            saveError = nil
        } catch {
            saveError = error.readableMessage
            return false
        }

        await load()
        return true
    }
}
