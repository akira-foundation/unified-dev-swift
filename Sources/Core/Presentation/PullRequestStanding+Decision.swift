import Foundation

public extension PullRequestStanding {
    static func of(
        branch: String,
        baseBranch: String,
        ahead: Int = 0,
        aheadIsCapped: Bool = false,
        pullRequest: PullRequest?,
        localWork: LocalWork? = nil,
        hasRemote: Bool = true
    ) -> PullRequestStanding {
        let mark = aheadMark(ahead, isCapped: aheadIsCapped)
        let count = aheadSentence(ahead, base: baseBranch, isCapped: aheadIsCapped)

        guard hasRemote else {
            return PullRequestStanding(
                headline: branch,
                target: baseBranch,
                ahead: mark,
                aheadAnnouncement: count,
                note: "No remote, so nowhere to push",
                sentence: [
                    count.map { "\(branch) is \($0)." },
                    "This project has no remote, so there is nowhere to push this branch and no"
                        + " pull request to open.",
                ].compactMap { $0 }.joined(separator: " ")
            )
        }

        guard let pullRequest else {
            return withoutPullRequest(
                branch: branch,
                baseBranch: baseBranch,
                mark: mark,
                count: count,
                localWork: localWork
            )
        }

        if pullRequest.isMerged { return merged(pullRequest, baseBranch: baseBranch) }
        if pullRequest.isClosed { return closed(pullRequest) }

        return open(pullRequest, baseBranch: baseBranch, localWork: localWork)
    }

    private static func withoutPullRequest(
        branch: String,
        baseBranch: String,
        mark: String?,
        count: String?,
        localWork: LocalWork?
    ) -> PullRequestStanding {
        let hasWork = mark != nil || localWork?.hasUncommitted == true
        return PullRequestStanding(
            headline: branch,
            target: baseBranch,
            tone: .accent,
            ahead: mark,
            aheadAnnouncement: count,
            note: hasWork ? nil : "Nothing has changed on this branch yet",
            button: hasWork
                ? Button(
                    act: .openPullRequest,
                    sentence: "Ask this workspace's agent to push \(branch) and open a pull request"
                        + " against \(baseBranch), following this project's pull request instructions."
                )
                : nil,
            current: .commits,
            path: PullRequestStep.whole,
            links: [diffLink],
            sentence: [
                count.map { "\(branch) is \($0)." } ?? "\(branch) has nothing \(baseBranch) does not.",
                "No pull request yet.",
            ].joined(separator: " ")
        )
    }

    private static func merged(
        _ pullRequest: PullRequest, baseBranch: String
    ) -> PullRequestStanding {
        PullRequestStanding(
            headline: pullRequest.title,
            number: pullRequest.number,
            url: pullRequest.url,
            state: "Merged",
            tone: .merged,
            button: Button(
                act: .archive,
                sentence: "Remove this workspace's worktree. #\(pullRequest.number) is merged into"
                    + " \(baseBranch), so this asks first only when something here exists nowhere else."
            ),
            sentence: "#\(pullRequest.number) \(pullRequest.title) is merged into \(baseBranch)."
        )
    }

    private static func closed(_ pullRequest: PullRequest) -> PullRequestStanding {
        PullRequestStanding(
            headline: pullRequest.title,
            number: pullRequest.number,
            url: pullRequest.url,
            state: "Closed",
            current: .pullRequest,
            path: PullRequestStep.whole,
            links: [diffLink, page(pullRequest)],
            sentence: "#\(pullRequest.number) \(pullRequest.title) was closed without merging."
        )
    }

    private static func open(
        _ pullRequest: PullRequest,
        baseBranch: String,
        localWork: LocalWork?
    ) -> PullRequestStanding {
        let status = pullRequest.status(local: localWork)
        let step = step(for: status.remedy, checks: pullRequest.checks)
        let act = act(for: status.remedy, checks: pullRequest.checks)

        var links = [diffLink, page(pullRequest)]
        if InspectorTab.hasChecks(pullRequest) { links.append(checksLink) }
        if status.canMerge { links.append(mergeLink) }

        return PullRequestStanding(
            headline: pullRequest.title,
            number: pullRequest.number,
            url: pullRequest.url,
            state: status.text,
            tone: tone(for: status.remedy, checks: pullRequest.checks, isDraft: pullRequest.isDraft),
            note: status.detail,
            button: act.map {
                Button(act: $0, sentence: sentence(for: $0, pullRequest, baseBranch: baseBranch))
            },
            current: step,
            path: PullRequestStep.whole,
            links: links,
            sentence: [
                "#\(pullRequest.number) \(pullRequest.title)",
                status.text,
                status.detail,
                status.blockedReason,
            ].compactMap { $0 }.joined(separator: "\n")
        )
    }

    private static func step(
        for remedy: PullRequestStatus.Remedy, checks: PullRequest.Checks
    ) -> PullRequestStep {
        switch remedy {
        case .fixConflicts: .merge
        case .push, .commitAndPush: .commits
        case .markReadyForReview: .pullRequest
        case .merge: checks == .passing || checks == .none ? .merge : .checks
        }
    }

    private static func tone(
        for remedy: PullRequestStatus.Remedy, checks: PullRequest.Checks, isDraft: Bool
    ) -> Tone {
        switch remedy {
        case .fixConflicts: .warning
        case .markReadyForReview: .quiet
        case .push, .commitAndPush: .accent
        case .merge:
            switch checks {
            case .failing: .danger
            case .unavailable: .warning
            case .pending, .passing, .none: isDraft ? .quiet : .accent
            }
        }
    }

    private static func act(
        for remedy: PullRequestStatus.Remedy, checks: PullRequest.Checks
    ) -> Act? {
        switch remedy {
        case .fixConflicts: .askToFixConflicts
        case .push: .push
        case .commitAndPush: .commitAndPush
        case .markReadyForReview: .markReadyForReview
        case .merge: checks == .failing ? .askToFixChecks : .merge
        }
    }

    private static func sentence(
        for act: Act, _ pullRequest: PullRequest, baseBranch: String
    ) -> String {
        let number = pullRequest.number
        let branch = pullRequest.branch.isEmpty ? "this branch" : pullRequest.branch
        switch act {
        case .askToFixConflicts:
            return "Write a request into this workspace's composer asking its agent to bring"
                + " \(baseBranch) into this worktree and resolve the conflicts here. Nothing is sent"
                + " until you send it, and #\(number) is not merged."
        case .askToFixChecks:
            return "Write a request into this workspace's composer, with the failing check's log in"
                + " it, asking its agent to fix what #\(number) broke. Nothing is sent until you"
                + " send it."
        case .push, .commitAndPush:
            let what = act == .push ? "push" : "commit what is here and push"
            return "Ask this workspace's agent to \(what) on \(branch), so #\(number) is what is on"
                + " this disk."
        case .markReadyForReview:
            return "Ask this workspace's agent to mark #\(number) ready for review on GitHub."
        case .merge:
            return "Merge #\(number) into \(baseBranch), or choose another method from the chevron."
        case .openPullRequest, .archive:
            return "Open #\(number) on GitHub."
        }
    }

    private static var diffLink: PullRequestStepLink {
        PullRequestStepLink(
            step: .commits, reach: .diff, announcement: "Opens the diff for this branch"
        )
    }

    private static func page(_ pullRequest: PullRequest) -> PullRequestStepLink {
        PullRequestStepLink(
            step: .pullRequest,
            reach: .pullRequestPage(pullRequest.url),
            announcement: "Opens #\(pullRequest.number) on GitHub"
        )
    }

    private static var checksLink: PullRequestStepLink {
        PullRequestStepLink(
            step: .checks, reach: .checks, announcement: "Opens this pull request's checks"
        )
    }

    private static var mergeLink: PullRequestStepLink {
        PullRequestStepLink(
            step: .merge, reach: .merge, announcement: "Opens the merge, where you choose how it lands"
        )
    }
}
