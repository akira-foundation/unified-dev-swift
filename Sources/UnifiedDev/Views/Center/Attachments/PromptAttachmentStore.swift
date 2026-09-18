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
        var released: [PromptAttachment] = []
    }

    @ObservationIgnored private var bySession: [String: SessionAttachments] = [:]

    private init() {}

    func attachments(for sessionID: String) -> [PromptAttachment] {
        box(for: sessionID).list ?? []
    }

    func load(sessionID: String) {
        let box = box(for: sessionID)
        guard box.list == nil else { return }
        box.released = Self.restore(key: Self.releasedKey(sessionID))
        box.list = Self.restore(key: Self.key(sessionID))
    }

    private func box(for sessionID: String) -> SessionAttachments {
        if let held = bySession[sessionID] { return held }
        let made = SessionAttachments()
        bySession[sessionID] = made
        return made
    }

    @discardableResult
    func hold(_ draft: String, sessionID: String, mounting: Bool) -> [String] {
        load(sessionID: sessionID)
        let box = box(for: sessionID)
        let active = box.list ?? []
        let released = box.released
        let hold = mounting
            ? AttachmentHold.mounting(active: active.map(\.path), released: released.map(\.path), in: draft)
            : AttachmentHold.editing(active: active.map(\.path), released: released.map(\.path), in: draft)
        guard hold.changesHold else { return hold.adopting }

        let releasing = Set(hold.releasing)
        let reinstating = Set(hold.reinstating)
        let kept = active.filter { !releasing.contains($0.path) }
        let keptPaths = Set(kept.map(\.path))
        let back = released.filter { reinstating.contains($0.path) && !keptPaths.contains($0.path) }
        let stillReleased = released.filter { !reinstating.contains($0.path) }
            + active.filter { releasing.contains($0.path) }
        apply(kept + back, released: stillReleased, to: sessionID)
        return hold.adopting
    }

    func restoreDraftAttachments(_ draft: String, sessionID: String) {
        hold(draft, sessionID: sessionID, mounting: true)
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
        let released = box(for: sessionID).released
        var known: [String: String] = [:]
        for attachment in released + existing where !attachment.source.isEmpty {
            known[attachment.source] = attachment.path
        }
        var taken = Set((existing + released).map(\.filename))
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

        let revived = released.filter { result.paths.contains($0.path) }
        guard !result.made.isEmpty || !revived.isEmpty else { return result }
        let revivedIDs = Set(revived.map(\.id))
        apply(
            attachments(for: sessionID) + revived + result.made,
            released: box(for: sessionID).released.filter { !revivedIDs.contains($0.id) },
            to: sessionID
        )
        return result
    }

    func remove(_ attachment: PromptAttachment, sessionID: String, workspace: String) {
        remove([attachment], sessionID: sessionID, workspace: workspace)
    }

    func remove(_ attachments: [PromptAttachment], sessionID: String, workspace: String) {
        let ids = Set(attachments.map(\.id))
        guard !ids.isEmpty else { return }
        apply(
            self.attachments(for: sessionID).filter { !ids.contains($0.id) },
            released: box(for: sessionID).released.filter { !ids.contains($0.id) },
            to: sessionID
        )
        Task.detached(priority: .utility) {
            for attachment in attachments {
                AttachmentFiles.discard(attachment, workspace: workspace)
            }
        }
    }

    func clear(sessionID: String) {
        apply([], released: [], to: sessionID)
    }

    func settle(sent text: String, sessionID: String, workspace: String) {
        let held = attachments(for: sessionID) + box(for: sessionID).released
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
        Self.persist(attachments, key: Self.key(sessionID))
    }

    private func apply(
        _ attachments: [PromptAttachment], released: [PromptAttachment], to sessionID: String
    ) {
        box(for: sessionID).released = released
        Self.persist(released, key: Self.releasedKey(sessionID))
        apply(attachments, to: sessionID)
    }

    private static func key(_ sessionID: String) -> String { "composer.attachments.\(sessionID)" }

    private static func releasedKey(_ sessionID: String) -> String {
        "composer.attachments.released.\(sessionID)"
    }

    private static func persist(_ attachments: [PromptAttachment], key: String) {
        let defaults = UserDefaults.standard
        guard !attachments.isEmpty else {
            defaults.removeObject(forKey: key)
            return
        }
        guard let data = try? JSONEncoder().encode(attachments) else { return }
        defaults.set(data, forKey: key)
    }

    private static func restore(key: String) -> [PromptAttachment] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let attachments = try? JSONDecoder().decode([PromptAttachment].self, from: data)
        else { return [] }
        return attachments
    }
}
