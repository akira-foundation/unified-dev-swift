import Foundation

public enum IssueFilingOutcome: Sendable, Equatable {
    case filed(FiledIssue)
    case page(images: Int, reason: IssueFilingRoute.PageReason)
}

public enum IssueFilingRoute {
    public enum Route: Sendable, Equatable {
        case gh
        case page
    }

    public enum PageReason: Sendable, Equatable {
        case noGh
        case ghRefused(String)
    }

    public static func route(for access: GitHubAccess) -> Route {
        switch access {
        case .ready: .gh
        case .notInstalled, .signedOut: .page
        }
    }

    public static func sentence(for outcome: IssueFilingOutcome) -> String {
        switch outcome {
        case .filed(let issue): sentence(for: issue)
        case .page(let images, let reason): pageSentence(images: images, reason: reason)
        }
    }

    public static func link(for outcome: IssueFilingOutcome) -> URL? {
        guard case .filed(let issue) = outcome else { return nil }
        return issue.url
    }

    private static func sentence(for issue: FiledIssue) -> String {
        let opened = "Issue #\(issue.number) is open on \(AppRepository.slug)."

        switch issue.attachments {
        case .none:
            return opened
        case .attached(let count):
            return "\(opened) \(Counted.of(count, "screenshot")) went with it."
        case .notAttached(let count):
            return "\(opened) \(Counted.of(count, "screenshot")) could not be uploaded, so the "
                + "issue is open in your browser, with \(Counted.word(count, "it", plural: "them")) "
                + "waiting in the Finder window beside it to be dragged in."
        }
    }

    private static func pageSentence(images: Int, reason: PageReason) -> String {
        let opening = switch reason {
        case .noGh:
            "gh is not signed in here, so the new issue page is open in your browser with your "
                + "report already in it."
        case .ghRefused(let said):
            "gh could not open the issue (\(said)), so the new issue page is open in your "
                + "browser with your report already in it."
        }

        guard images > 0 else { return "\(opening) Press Submit there to file it." }
        return "\(opening) \(Counted.of(images, "screenshot")) \(Counted.word(images, "is", plural: "are")) "
            + "in the Finder window beside it, to be dragged in before you submit."
    }
}
