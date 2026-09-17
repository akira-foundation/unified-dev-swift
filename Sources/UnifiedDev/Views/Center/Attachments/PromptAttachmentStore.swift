import SwiftUI
import Observation
import Core

@MainActor
@Observable
final class PromptAttachmentStore {
    static let shared = PromptAttachmentStore()

    @Observable
    final class SessionAttachments {
        var list: [PromptAttachment]?
    }

    @ObservationIgnored private var bySession: [String: SessionAttachments] = [:]

    private init() {}

    func attachments(for sessionID: String) -> [PromptAttachment] {
        box(for: sessionID).list ?? []
    }

    func load(sessionID: String) {
        let box = box(for: sessionID)
        guard box.list == nil else { return }
        box.list = Self.restore(sessionID: sessionID)
    }

    private func box(for sessionID: String) -> SessionAttachments {
        if let held = bySession[sessionID] { return held }
        let made = SessionAttachments()
        bySession[sessionID] = made
        return made
    }

    func restoreDraftAttachments(_ draft: String, sessionID: String) {
        load(sessionID: sessionID)
        var restored = attachments(for: sessionID)
        var paths = Set(restored.map(\.path))
        for path in AttachmentDraft.parse(draft).paths where paths.insert(path).inserted {
            restored.append(.sent(path: path))
        }
        apply(restored, to: sessionID)
    }

    struct Added: Sendable {
        var made: [PromptAttachment] = []
        var paths: [String] = []
        var failures: [String] = []
    }

    @discardableResult
    func add(
        _ sources: [AttachmentSource],
        sessionID: String,
        workspace: String
    ) async -> Added {
        let existing = attachments(for: sessionID)
        var known: [String: String] = [:]
        for attachment in existing where !attachment.source.isEmpty {
            known[attachment.source] = attachment.path
        }
        var taken = Set(existing.map(\.filename))
        enum Slot { case attached(String), fresh(AttachmentSource), duplicate(ofWanted: Int) }
        var slots: [Slot] = []
        var pending: [String: Int] = [:]
        var freshCount = 0

        for source in sources {
            if case .file(let url) = source {
                let path = url.standardizedFileURL.path
                if let index = pending[path] {
                    slots.append(.duplicate(ofWanted: index))
                    continue
                }
                if let already = known[path] {
                    slots.append(.attached(already))
                    continue
                }
                known[path] = ""
                pending[path] = freshCount
                taken.insert(url.lastPathComponent)
                slots.append(.fresh(source))
                freshCount += 1
                continue
            }
            let name = PastedAttachment.uniqued(source.filename, avoiding: taken)
            taken.insert(name)
            slots.append(.fresh(source.named(name)))
            freshCount += 1
        }

        let wanted = slots.compactMap { slot -> AttachmentSource? in
            guard case .fresh(let source) = slot else { return nil }
            return source
        }

        let copied = await Task.detached(priority: .userInitiated) {
            () -> ([Int: PromptAttachment], [String]) in
            var made: [Int: PromptAttachment] = [:]
            var failures: [String] = []
            for (index, source) in wanted.enumerated() {
                do {
                    made[index] = try AttachmentFiles.attach(source, workspace: workspace)
                } catch {
                    failures.append(error.readableMessage)
                }
            }
            return (made, failures)
        }.value

        var result = Added(failures: copied.1)
        var fresh = 0
        for slot in slots {
            switch slot {
            case .attached(let path):
                result.paths.append(path)
            case .fresh:
                defer { fresh += 1 }
                guard let made = copied.0[fresh] else { continue }
                result.made.append(made)
                result.paths.append(made.path)
            case .duplicate(let index):
                guard let made = copied.0[index] else { continue }
                result.paths.append(made.path)
            }
        }

        guard !result.made.isEmpty else { return result }
        apply(attachments(for: sessionID) + result.made, to: sessionID)
        return result
    }

    func remove(_ attachment: PromptAttachment, sessionID: String, workspace: String) {
        remove([attachment], sessionID: sessionID, workspace: workspace)
    }

    func remove(_ attachments: [PromptAttachment], sessionID: String, workspace: String) {
        let ids = Set(attachments.map(\.id))
        guard !ids.isEmpty else { return }
        apply(self.attachments(for: sessionID).filter { !ids.contains($0.id) }, to: sessionID)
        Task.detached(priority: .utility) {
            for attachment in attachments {
                AttachmentFiles.discard(attachment, workspace: workspace)
            }
        }
    }

    func clear(sessionID: String) {
        apply([], to: sessionID)
    }

    func settle(sent text: String, sessionID: String, workspace: String) {
        let held = attachments(for: sessionID)
        let named = Set(AttachmentDraft.parse(text, paths: held.map(\.path)).paths)
        remove(held.filter { !named.contains($0.path) }, sessionID: sessionID, workspace: workspace)
        clear(sessionID: sessionID)
    }

    func annotate(paths: [String], with comment: BrowserImageComment, sessionID: String) {
        let paths = Set(paths)
        let updated = attachments(for: sessionID).map { attachment in
            var attachment = attachment
            if paths.contains(attachment.path) { attachment.imageComment = comment }
            return attachment
        }
        apply(updated, to: sessionID)
    }

    private func apply(_ attachments: [PromptAttachment], to sessionID: String) {
        box(for: sessionID).list = attachments
        Self.persist(attachments, sessionID: sessionID)
    }

    private static func key(_ sessionID: String) -> String { "composer.attachments.\(sessionID)" }

    private static func persist(_ attachments: [PromptAttachment], sessionID: String) {
        let defaults = UserDefaults.standard
        guard !attachments.isEmpty else {
            defaults.removeObject(forKey: key(sessionID))
            return
        }
        guard let data = try? JSONEncoder().encode(attachments) else { return }
        defaults.set(data, forKey: key(sessionID))
    }

    private static func restore(sessionID: String) -> [PromptAttachment] {
        guard let data = UserDefaults.standard.data(forKey: key(sessionID)),
              let attachments = try? JSONDecoder().decode([PromptAttachment].self, from: data)
        else { return [] }
        return attachments
    }
}
