import SwiftUI
import Observation
import Core

@MainActor
@Observable
final class DiffEditSession {
    static let shared = DiffEditSession()

    private init() {}

    struct Editor: Sendable, Equatable {
        var baseline: EditableFile
        var region: DiffEditRegion
        var status: Status
    }

    enum Status: Sendable, Equatable {
        case editing
        case stale(String)
        case failed(String)

        var warning: String? {
            switch self {
            case .editing: nil
            case let .stale(message), let .failed(message): message
            }
        }
    }

    private(set) var editors: [String: Editor] = [:]

    private(set) var typed: [String: String] = [:]

    func editor(for path: String) -> Editor? { editors[path] }
    func text(for path: String) -> String { typed[path] ?? "" }
    func isOpen(_ path: String) -> Bool { editors[path] != nil }

    func isEdited(_ path: String) -> Bool {
        guard let editor = editors[path], let text = typed[path] else { return false }
        return editor.region.isEdited(text)
    }

    func binding(for path: String) -> Binding<String> {
        Binding(
            get: { self.typed[path] ?? "" },
            set: { newValue in
                guard self.editors[path] != nil else { return }
                self.typed[path] = newValue
                if case .failed = self.editors[path]?.status { self.editors[path]?.status = .editing }
            }
        )
    }

    func begin(path absolutePath: String, at line: Int, hunks: [DiffHunk]) async -> String? {
        if isEdited(absolutePath), let region = editors[absolutePath]?.region {
            return "You are already editing \(Self.span(of: region)). Save or cancel that first."
        }

        let outcome = await Task.detached(priority: .userInitiated) {
            Self.locating(absolutePath, at: line, hunks: hunks)
        }.value

        switch outcome {
        case let .opened(editor):
            editors[absolutePath] = editor
            typed[absolutePath] = editor.region.text
            return nil
        case let .refused(message):
            return message
        }
    }

    func save(path absolutePath: String) async -> Bool {
        guard let editor = editors[absolutePath], let text = typed[absolutePath],
              editor.region.isEdited(text)
        else { return false }

        let outcome = await Task.detached(priority: .userInitiated) {
            Self.writing(text, of: editor.region, over: editor.baseline)
        }.value

        switch outcome {
        case .written:
            close(path: absolutePath)
            return true
        case let .refused(message):
            editors[absolutePath]?.status = .failed(message)
            return false
        }
    }

    func close(path absolutePath: String) {
        editors[absolutePath] = nil
        typed[absolutePath] = nil
    }

    func recheck(path absolutePath: String, contents: String?) {
        guard let editor = editors[absolutePath] else { return }
        if case .failed = editor.status { return }

        let warning = DiffEdit.staleWarning(
            filename: editor.baseline.filename, baseline: editor.baseline.text, contents: contents
        )
        let next: Status = warning.map(Status.stale) ?? .editing
        guard next != editor.status else { return }
        editors[absolutePath]?.status = next
    }

    static func span(of region: DiffEditRegion) -> String {
        region.lineCount == 1
            ? "line \(region.firstLine)"
            : "lines \(region.firstLine) to \(region.lastLine)"
    }

    private enum Located: Sendable {
        case opened(Editor)
        case refused(String)
    }

    private enum Written: Sendable {
        case written
        case refused(String)
    }

    nonisolated private static func locating(
        _ path: String, at line: Int, hunks: [DiffHunk]
    ) -> Located {
        do {
            let file = try FileEditor.read(path)
            let region = try DiffEdit.region(at: line, in: hunks, fileText: file.text)
            return .opened(Editor(baseline: file, region: region, status: .editing))
        } catch let error as FileEditorError {
            return .refused(message(for: error))
        } catch let error as DiffEditRefusal {
            return .refused(message(for: error))
        } catch {
            return .refused(error.localizedDescription)
        }
    }

    nonisolated private static func writing(
        _ text: String, of region: DiffEditRegion, over baseline: EditableFile
    ) -> Written {
        do {
            let whole = try DiffEdit.apply(text, of: region, to: baseline.text)
            try FileEditor.write(whole, over: baseline)
            return .written
        } catch let error as DiffEditRefusal {
            return .refused(message(for: error))
        } catch let error as FileEditorError {
            return .refused(message(for: error))
        } catch {
            return .refused(error.localizedDescription)
        }
    }

    nonisolated private static func message(for error: some LocalizedError) -> String {
        error.errorDescription ?? "\(error)"
    }
}
