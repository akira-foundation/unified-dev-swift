import SwiftUI
import Observation
import Core

@MainActor
@Observable
final class FileEditSession {
    static let shared = FileEditSession()

    private init() {}

    typealias Draft = SourceDraft

    enum Status: Equatable {
        case idle
        case loading
        case unavailable(String)
        case failed(String)
        case saved
    }

    private(set) var drafts: [String: Draft] = [:]
    private(set) var diskVersions: [String: EditableFile] = [:]
    private var operations: [String: UUID] = [:]
    private(set) var saving: Set<String> = []
    private(set) var status: [String: Status] = [:]

    func status(for path: String) -> Status { status[path] ?? .idle }
    func draft(for path: String) -> Draft? { drafts[path] }
    func isDirty(_ path: String) -> Bool { drafts[path]?.isDirty ?? false }

    func binding(for path: String) -> Binding<String> {
        Binding(
            get: { self.drafts[path]?.text ?? "" },
            set: { newValue in
                guard var draft = self.drafts[path] else { return }
                draft.text = newValue
                self.drafts[path] = draft
                if case .saved = self.status(for: path) { self.status[path] = .idle }
            }
        )
    }

    func load(path absolutePath: String) async {
        guard drafts[absolutePath]?.isDirty != true, !saving.contains(absolutePath) else { return }
        if drafts[absolutePath] == nil { status[absolutePath] = .loading }

        let operation = UUID()
        operations[absolutePath] = operation
        let outcome = await Task.detached(priority: .userInitiated) {
            Self.reading(absolutePath)
        }.value
        guard !Task.isCancelled, operations[absolutePath] == operation,
              drafts[absolutePath]?.isDirty != true, !saving.contains(absolutePath) else { return }

        switch outcome {
        case let .success(file):
            drafts[absolutePath] = Draft(baseline: file, text: file.text)
            status[absolutePath] = .idle
        case let .failure(error):
            status[absolutePath] = .unavailable(Self.message(for: error))
        }
    }

    func save(path absolutePath: String) async {
        guard let draft = drafts[absolutePath], draft.isDirty, !saving.contains(absolutePath) else { return }
        saving.insert(absolutePath)
        defer { saving.remove(absolutePath) }
        let operation = UUID()
        operations[absolutePath] = operation

        let text = draft.text
        let baseline = draft.baseline
        let outcome = await Task.detached(priority: .userInitiated) {
            Self.writing(text, over: baseline)
        }.value
        guard operations[absolutePath] == operation else { return }

        switch outcome {
        case let .success(saved):
            guard var current = drafts[absolutePath] else { return }
            current.didSave(saved)
            drafts[absolutePath] = current
            diskVersions[absolutePath] = nil
            status[absolutePath] = .saved
        case let .failure(error):
            status[absolutePath] = .failed(Self.message(for: error))
        }
    }

    func refresh(path: String) async {
        guard let baseline = drafts[path]?.baseline, !saving.contains(path) else { return }
        let operation = UUID()
        operations[path] = operation
        let outcome = await Task.detached(priority: .utility) { Self.reading(path) }.value
        guard !Task.isCancelled, operations[path] == operation, !saving.contains(path),
              let current = drafts[path], current.baseline == baseline else { return }
        switch outcome {
        case let .success(file):
            if file.text == current.baseline.text { diskVersions[path] = nil; return }
            var refreshed = current
            if !refreshed.acceptDisk(file) { diskVersions[path] = file } else {
                drafts[path] = refreshed
                diskVersions[path] = nil
                status[path] = .idle
            }
        case let .failure(error):
            status[path] = .failed(Self.message(for: error))
        }
    }

    func keepDraftOverDisk(path: String) async {
        guard let disk = diskVersions[path], var draft = drafts[path], !saving.contains(path) else { return }
        draft.baseline = disk
        drafts[path] = draft
        await save(path: path)
    }

    func reload(path absolutePath: String) async {
        guard !saving.contains(absolutePath) else { return }
        diskVersions[absolutePath] = nil
        drafts[absolutePath] = nil
        status[absolutePath] = .idle
        await load(path: absolutePath)
    }

    func discard(path absolutePath: String) {
        operations[absolutePath] = nil
        diskVersions[absolutePath] = nil
        drafts[absolutePath] = nil
        status[absolutePath] = nil
    }

    nonisolated private static func reading(_ path: String) -> Result<EditableFile, FileEditorError> {
        do { return .success(try FileEditor.read(path)) } catch { return .failure(error) }
    }

    nonisolated private static func writing(
        _ text: String, over baseline: EditableFile
    ) -> Result<EditableFile, FileEditorError> {
        do {
            return .success(try FileEditor.write(text, over: baseline))
        } catch {
            return .failure(error)
        }
    }

    private static func message(for error: FileEditorError) -> String {
        error.errorDescription ?? "\(error)"
    }
}
