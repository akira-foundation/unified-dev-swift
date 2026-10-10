import AppKit
import Foundation
import Core

@MainActor
enum IssueFiling {
    static func file(
        kind: Feedback.Kind,
        message: String,
        logs: String?,
        environment: Feedback.Environment,
        images: [FeedbackImage]
    ) async -> IssueFilingOutcome {
        let folder = images.isEmpty ? nil : await written(images)
        let carried = folder?.files.count ?? 0

        let title = IssueReport.title(from: message, kind: kind)
        let body = IssueReport.body(
            message: message,
            kind: kind,
            environment: environment,
            logs: logs,
            imageCount: carried
        )
        let labels = IssueReport.labels(for: kind)

        if let reason = IssueFilingRoute.pageReason(for: await GitHub.access()) {
            return page(title: title, body: body, labels: labels, folder: folder, reason: reason)
        }

        let filed = await GitHub.createIssue(
            slug: AppRepository.slug,
            title: title,
            body: body,
            labels: labels,
            images: folder?.files.map(\.path) ?? []
        )

        switch filed {
        case .success(let issue):
            carry(issue, folder: folder)
            return .filed(issue)
        case .failure(.unanswered(let said)):
            return .refused(said)
        case .failure(.refused(let said)):
            return page(
                title: title, body: body, labels: labels, folder: folder,
                reason: .ghRefused(said)
            )
        }
    }

    private struct Folder: Sendable {
        let root: URL
        let files: [URL]
    }

    private static func carry(_ issue: FiledIssue, folder: Folder?) {
        guard let folder else { return }

        switch issue.attachments {
        case .none, .attached:
            try? FileManager.default.removeItem(at: folder.root)
        case .partly, .notAttached:
            NSWorkspace.shared.open(issue.url)
            folder.files.first.map { Reveal.inFinder($0.path) }
        }
    }

    private static func page(
        title: String,
        body: String,
        labels: [String],
        folder: Folder?,
        reason: IssueFilingRoute.PageReason
    ) -> IssueFilingOutcome {
        NSWorkspace.shared.open(
            AppRepository.newIssueURL(
                title: title, body: body, labels: labels, cut: IssueReport.cut
            )
        )
        folder?.files.first.map { Reveal.inFinder($0.path) }
        return .page(images: folder?.files.count ?? 0, reason: reason)
    }

    private static func written(_ images: [FeedbackImage]) async -> Folder? {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("Unified Dev report \(UUID().uuidString.prefix(8))")
        let named = images.enumerated().map { (name(of: $1, at: $0), $1.data) }

        return await Task.detached(priority: .userInitiated) {
            guard (try? FileManager.default.createDirectory(
                at: root, withIntermediateDirectories: true
            )) != nil else { return nil }

            var written: [URL] = []
            for (name, data) in named {
                let file = root.appendingPathComponent(name)
                guard (try? data.write(to: file)) != nil else { continue }
                written.append(file)
            }

            guard !written.isEmpty else {
                try? FileManager.default.removeItem(at: root)
                return nil
            }
            return Folder(root: root, files: written)
        }.value
    }

    private static func name(of image: FeedbackImage, at index: Int) -> String {
        "screenshot-\(index + 1).\(Feedback.fileExtension(for: image.contentType))"
    }
}
