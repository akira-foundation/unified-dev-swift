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
        let title = IssueReport.title(from: message, kind: kind)
        let body = IssueReport.body(
            message: message,
            kind: kind,
            environment: environment,
            logs: logs,
            imageCount: images.count
        )
        let labels = IssueReport.labels(for: kind)
        let folder = images.isEmpty ? nil : written(images)

        guard IssueFilingRoute.route(for: await GitHub.access()) == .gh else {
            return page(title: title, body: body, labels: labels, folder: folder, reason: .noGh)
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
        case .failure(let error):
            return page(
                title: title, body: body, labels: labels, folder: folder,
                reason: .ghRefused(error.message)
            )
        }
    }

    private struct Folder {
        let root: URL
        let files: [URL]
    }

    private static func carry(_ issue: FiledIssue, folder: Folder?) {
        guard case .notAttached = issue.attachments, let folder else {
            folder.map { try? FileManager.default.removeItem(at: $0.root) }
            return
        }

        NSWorkspace.shared.open(issue.url)
        folder.files.first.map { Reveal.inFinder($0.path) }
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

    private static func written(_ images: [FeedbackImage]) -> Folder? {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("Unified Dev report \(UUID().uuidString.prefix(8))")
        guard (try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true))
            != nil
        else { return nil }

        var written: [URL] = []
        for (index, image) in images.enumerated() {
            let file = root.appendingPathComponent(name(of: image, at: index))
            guard (try? image.data.write(to: file)) != nil else { continue }
            written.append(file)
        }

        guard !written.isEmpty else {
            try? FileManager.default.removeItem(at: root)
            return nil
        }
        return Folder(root: root, files: written)
    }

    private static func name(of image: FeedbackImage, at index: Int) -> String {
        let suffix = Feedback.fileExtension(for: image.contentType)
        return "screenshot-\(index + 1).\(suffix)"
    }
}
