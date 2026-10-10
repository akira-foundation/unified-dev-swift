import Foundation

public enum IssueFilingOutcome: Sendable, Equatable {
    case filed(FiledIssue)
    case page(images: Int, reason: IssueFilingRoute.PageReason)
    case refused(String)

    public var keepsTheText: Bool {
        switch self {
        case .filed: false
        case .page, .refused: true
        }
    }
}

public enum IssueFilingRoute {
    public enum Route: Sendable, Equatable {
        case gh
        case page
    }

    public enum PageReason: Sendable, Equatable {
        case ghMissing
        case ghSignedOut
        case ghRefused(String)
    }

    public static func route(for access: GitHubAccess) -> Route {
        pageReason(for: access) == nil ? .gh : .page
    }

    public static func pageReason(for access: GitHubAccess) -> PageReason? {
        switch access {
        case .ready: nil
        case .notInstalled: .ghMissing
        case .signedOut: .ghSignedOut
        }
    }

    public static func sentence(for outcome: IssueFilingOutcome) -> String {
        switch outcome {
        case .filed(let issue): sentence(for: issue)
        case .page(let images, let reason): pageSentence(images: images, reason: reason)
        case .refused(let said): said
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
        case .partly(let count):
            return "\(opened) gh did not finish uploading \(Counted.of(count, "screenshot")), so "
                + "the issue is open in your browser and the files are in the Finder window "
                + "beside it. Drag in whichever of them the issue is missing."
        case .notAttached(let count):
            return "\(opened) This gh cannot attach files, so "
                + "\(Counted.of(count, "screenshot")) stayed behind: the issue is open in your "
                + "browser, with \(Counted.word(count, "it", plural: "them")) waiting in the "
                + "Finder window beside it to be dragged in."
        }
    }

    private static func pageSentence(images: Int, reason: PageReason) -> String {
        let opening = switch reason {
        case .ghMissing:
            "gh is not installed here, so the new issue page is open in your browser with your "
                + "report already in it."
        case .ghSignedOut:
            "gh is not signed in here, so the new issue page is open in your browser with your "
                + "report already in it."
        case .ghRefused(let said):
            "gh could not open the issue (\(said)), so the new issue page is open in your "
                + "browser with your report already in it."
        }

        let submit = "Press Submit there to file it, and your text stays here until you do."
        guard images > 0 else { return "\(opening) \(submit)" }
        return "\(opening) \(Counted.of(images, "screenshot")) "
            + "\(Counted.word(images, "is", plural: "are")) in the Finder window beside it, to "
            + "be dragged in before you submit. \(submit)"
    }
}
