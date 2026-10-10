import SwiftUI
import Core

extension WorkspaceModel {
    func requestPullRequest(overrides: PromptOverrides = PromptOverrides()) async -> String? {
        let template = overrides.template(for: .createPullRequest)
        let wanted = Set(PromptTemplate.variableNames(in: template))

        if wanted.contains(PromptRegistry.CreatePullRequest.changes) {
            await refreshChanges()
        }

        guard let session = await sessionToWriteInto() else {
            return "Could not open a session in \(workspace.name) to send the request to."
        }

        let context = PullRequestPromptContext(
            workspaceName: workspace.name,
            branch: workspace.branch,
            baseBranch: workspace.baseBranch,
            task: wanted.contains(PromptRegistry.CreatePullRequest.task) ? await openingPrompt() : "",
            changes: wanted.contains(PromptRegistry.CreatePullRequest.changes)
                ? PullRequestPromptContext.changeSummary(changedFiles)
                : ""
        )
        let render = context.render(template: template)

        activeSessionID = session.id
        isExpectingPullRequest = true
        await transcript(for: session).submit(await pullRequestTurn(text: render.text))
        return nil
    }

    func requestPush(overrides: PromptOverrides = PromptOverrides()) async -> String? {
        let template = overrides.template(for: .pushLocalWork)
        let wanted = Set(PromptTemplate.variableNames(in: template))

        if wanted.contains(PromptRegistry.PushLocalWork.changes) {
            await refreshChanges()
        }

        guard let session = await sessionToWriteInto() else {
            return "Could not open a session in \(workspace.name) to send the request to."
        }

        let render = PromptTemplate.render(template, values: [
            PromptRegistry.PushLocalWork.workspace: workspace.name,
            PromptRegistry.PushLocalWork.branch: workspace.branch,
            PromptRegistry.PushLocalWork.baseBranch: workspace.baseBranch,
            PromptRegistry.PushLocalWork.changes:
                PullRequestPromptContext.changeSummary(changedFiles),
        ])

        activeSessionID = session.id
        await transcript(for: session).submit(render.text)
        return nil
    }

    func requestMarkReadyForReview(
        _ pullRequest: PullRequest,
        overrides: PromptOverrides = PromptOverrides()
    ) async -> String? {
        guard pullRequest.isOpen, pullRequest.isDraft else {
            return "This pull request is no longer an open draft."
        }
        guard let session = await sessionToWriteInto(titledIfNew: "Mark ready for review") else {
            return "Could not open a session in \(workspace.name) to send the request to."
        }

        let render = PromptTemplate.render(
            overrides.template(for: .markReadyForReview),
            values: [PromptRegistry.MarkReadyForReview.url: pullRequest.url]
        )
        activeSessionID = session.id
        await transcript(for: session).submit(render.text)
        return nil
    }

    func requestMerge(
        _ pullRequest: PullRequest,
        method: GitHub.MergeMethod,
        overrides: PromptOverrides = PromptOverrides()
    ) async -> String? {
        guard let session = await sessionToWriteInto(titledIfNew: "Merge") else {
            return "Could not open a session in \(workspace.name) to send the request to."
        }

        let context = MergePromptContext(
            workspaceName: workspace.name,
            number: pullRequest.number,
            title: pullRequest.title,
            branch: pullRequest.branch,
            baseBranch: workspace.baseBranch,
            method: method
        )
        let render = context.render(template: overrides.template(for: .mergePullRequest))

        let text = await turn(render.text, for: .merge)
        activeSessionID = session.id
        await transcript(for: session).submit(text)
        return nil
    }

    private func turn(_ text: String, for subject: ProjectInstructions.Subject) async -> String {
        await reloadSettings()
        let stated = ProjectInstructions.stated(subject, in: settings)
        let path = workspace.path
        let extra = await Task.detached(priority: .userInitiated) {
            ProjectInstructions.resolve(subject, in: path, stated: stated)
        }.value
        return ProjectInstructions.turn(text, for: subject, adding: extra)
    }

    func writeFixConflictsRequest(
        overrides: PromptOverrides = PromptOverrides()
    ) async -> String? {
        guard let pullRequest else { return "This branch has no pull request to resolve." }
        guard let session = await sessionToWriteInto(titledIfNew: "Fix merge conflicts") else {
            return "Could not open a session in \(workspace.name) to write the request into."
        }

        let context = FixConflictsPromptContext(
            workspaceName: workspace.name,
            number: pullRequest.number,
            branch: workspace.branch,
            baseBranch: workspace.baseBranch
        )
        let render = context.render(template: overrides.template(for: .fixConflicts))

        let path = workspace.path
        let rendered = render.text
        let asked = await Task.detached(priority: .userInitiated) {
            ConflictInstructions.asking(rendered, in: path)
        }.value
        activeSessionID = session.id
        return await ComposerHandoff.write(await turn(asked, for: .fixConflicts), to: self).failure
    }

    func writeCheckFailureRequest() async -> String? {
        guard let pullRequest else { return "This branch has no pull request to read checks from." }

        let asked = workspace
        let runs = await Task.detached(priority: .userInitiated) {
            try? await GitHub.checks(for: asked)
        }.value
        guard let runs else {
            return "Unified Dev could not ask GitHub for the checks on #\(pullRequest.number)."
        }

        let failed = runs.filter { CheckState($0) == .failed }
        guard !failed.isEmpty else {
            return "GitHub no longer reports a failed check on #\(pullRequest.number)."
        }
        return await writeCheckFailureRequest(for: failed)
    }

    func writeCheckFailureRequest(for failed: [CheckRun]) async -> String? {
        guard let pullRequest else { return "This branch has no pull request to read checks from." }
        guard let session = await sessionToWriteInto(titledIfNew: "Fix the failing checks") else {
            return "Could not open a session in \(workspace.name) to write the request into."
        }
        activeSessionID = session.id

        let carried = Array(failed.prefix(CheckFailureHandoff.mentionsCarried))
        var gathered: [CheckFailureHandoff.Mention] = []
        var logs: [AttachmentSource] = []

        for run in carried {
            var excerpt: CheckFailureHandoff.Excerpt?
            if let target = CheckFailureHandoff.logTarget(detailsURL: run.detailsURL),
               let log = try? await GitHub.checkRunLog(target, worktree: workspace.path) {
                excerpt = CheckFailureHandoff.excerpt(log)
            }
            if let excerpt {
                logs.append(
                    .text(excerpt.text, named: CheckFailureHandoff.logFilename(for: run.name))
                )
            }
            gathered.append(
                CheckFailureHandoff.Mention(
                    name: run.name,
                    workflow: run.workflowName,
                    detailsURL: run.detailsURL,
                    excerpt: excerpt
                )
            )
        }

        let mentions = gathered
        let more = failed.count - carried.count
        let number = pullRequest.number

        guard !logs.isEmpty else {
            return await ComposerHandoff.write(
                CheckFailureHandoff.request(mentions, moreFailed: more, number: number), to: self
            ).failure
        }

        return await ComposerHandoff.attach(logs, to: self, sessionID: session.id) { paths in
            CheckFailureHandoff.request(
                CheckFailureHandoff.carrying(mentions, logPaths: paths),
                moreFailed: more,
                number: number
            )
        }.failure
    }

    func readRemote() async {
        let repo = repo?.path ?? workspace.path
        let names = await Task.detached(priority: .utility) {
            try? await Git.remoteNames(of: repo)
        }.value
        guard let names else { return }
        let found = !names.isEmpty
        if hasRemote != found { hasRemote = found }
    }

    private func pullRequestTurn(text: String) async -> String {
        if let path = await PullRequestInstructions.ensure(in: workspace.path) {
            return PullRequestInstructions.asking(text, toFollow: path)
        }
        return text + "\n\n" + PullRequestInstructions.defaultMarkdown
    }

    private func openingPrompt() async -> String {
        guard let store else { return "" }
        for session in sessions {
            let messages = (try? await store.messages(sessionID: session.id, limit: 200)) ?? []
            guard let first = messages.first(where: { $0.kind == .user }),
                  let text = UserTurnPayload.text(from: first.payload) else { continue }
            return AttachmentDraft.withoutAttachments(AttachmentTrailer.split(text).body)
        }
        return ""
    }
}
