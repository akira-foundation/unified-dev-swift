import SwiftUI
import Core

/// The right hand column: what the agent changed, and what GitHub thinks of it.
///
/// Everything here is a thin arrangement of the pieces below it: the column's own top edge, what
/// the pull request strip has to say, the tab row, and whichever pane the tab row selected. The
/// strip itself is above the column rather than in it, in the title bar, at the width this pane
/// happens to be. See `TitleBarStrip`.
///
/// It shows no file contents. It used to: the list sat above a drawer that held the diff, and the
/// two shared the column's height, so a wide diff got a narrow pane and a long list got a short
/// one. Files open in the centre column now, which is where Conductor puts them and where there
/// is room for them, and this column went back to being a list of what changed.
struct InspectorView: View {
    let model: WorkspaceModel

    /// The one Connect GitHub sheet, presented from the column's root rather than from whichever
    /// control raised it, so the pull request strip and the checks tab share one presentation.
    @Bindable private var signIn = GitHubSignIn.shared

    var body: some View {
        VStack(spacing: 0) {
            // What the strip above just did, said in the column rather than in the band.
            //
            // Here rather than in the strip because the strip is one row tall and cannot grow:
            // see `PullRequestBar`. Here rather than below the tab row because it is the answer
            // to a button a few points above it, and an answer that appears under the tabs reads
            // as something about the list.
            if let notice = model.pullRequestNotice {
                InspectorNotice(notice: notice) { model.pullRequestNotice = nil }
                Hairline()
            }
            // The pane's own controls, at the top of the island. They were toolbar items for an
            // hour, and the bar they were in is the centre column's: an island that runs to the
            // top of the window has no bar above it to put anything in.
            InspectorIslandControls(model: model)

            // The tab row, and the boundary between it and the pane, as one band.
            //
            // The rule is drawn INSIDE the row's own height rather than stacked under it, which
            // is what makes this column's first line the same line as the centre column's. A tab
            // strip is `Metrics.barHeight` tall including the rule that closes it off (see
            // `tabStripMaterial`, where the rule sits behind the tabs for a reason of its own), so
            // a row of the same height with a rule added below it ends one point lower than the
            // row beside it. Measured off a two times capture at 1440 by 900: the centre column's
            // rule ran from y=83 and this one from y=85, two points of step across the join, which
            // is exactly the point this row used to spend on the top edge plus the point the rule
            // used to add underneath.
            //
            // **This half of the rule is deliberately not lit**, and it was for a fortnight. The
            // busy signal used to run here too, off the same epoch as the centre column's, and the
            // report on it was "there seems to be two going, one in middle pane, one in right".
            // Both halves were right on their own terms and that was the problem: they shared a
            // period and therefore not a speed, so two crests set off from two leading edges at
            // two rates, and what the eye counted was two objects rather than one thing passing
            // behind a divider. See `ActivityRule` for the continuous version that was measured
            // and not built.

            // What the list below is measured from, when it is not measured from everything.
            //
            // Under the tab row because it is a fact about the pane beneath it. On both file tabs
            // rather than only on Changes: the All files tree marks the files that differ, and it
            // marks them off the same list, so a narrowed scope quietly takes marks off that tree
            // too. A tab where the scope has an effect is a tab where it has to be explained. The
            // checks list is GitHub's and owes nothing to any of this.
            if model.inspectorTab != .checks, model.diffScope.isNarrowed {
                DiffScopeBand(
                    scope: model.diffScope,
                    fileCount: model.changedFiles.count,
                    note: model.scopeNote
                ) {
                    model.setDiffScope(.all)
                }
                Hairline()
            }

            content
                .frame(maxHeight: .infinity)

            if let failure = model.pullRequestRefreshFailure {
                RefreshFailureRow(failure: failure, hasPullRequest: model.pullRequest != nil)
            }

            // The branch, and what GitHub last said about it, along the foot of the pane. It used
            // to be a title bar accessory above everything, which put a band of its own between
            // the window's toolbar and the pane's own bar. A summary of what you are looking at
            // belongs where Finder and Mail put theirs, which is the bottom.
            PullRequestBar(model: model)
        }
        // An island, the way the sidebar is one under Tahoe: the WHOLE panel on a rounded plate
        // of the system's own glass, inset from the window's edges, and running from the top of
        // the window rather than from under the toolbar. The toolbar belongs to the centre column
        // now, so there is nothing above this to sit under.
        //
        // What it is not is an overlay. A SwiftUI inspector is a COLUMN: it takes width from the
        // centre rather than floating above it, so the content beside it stops at the divider and
        // does not run on underneath.
        .clipShape(.rect(cornerRadius: Metrics.corner, style: .continuous))
        .glassEffect(.regular, in: .rect(cornerRadius: Metrics.corner, style: .continuous))
        .padding(Metrics.spacingWide)
        .ignoresSafeArea(.container, edges: .top)
        // Filling the column, not sized to its contents.
        //
        // Top alignment was here because a flexible frame centres a child that does not fill it,
        // and the empty states do not: a worktree with nothing changed drew the column floating
        // in the middle. What fills it now is `content`, which takes the height the bar and the
        // foot leave over, so the bar sits at the top and the branch band at the bottom whatever
        // is between them. Aligning to the top instead collapsed the stack and left the band
        // hanging under the empty state with the pane blank below it.
        .sheet(item: $signIn.request) { request in
            GitHubSignInSheet(request: request) { connected in
                signIn.finish(connected: connected)
            }
        }
        // What the title bar accessory is as wide as, and therefore where the rule that carries
        // the pane divider to the top of the window sits. It used to be published by
        // `DetailSplitViewController`; the pane is a column of the window now and measures itself.
        .onGeometryChange(for: CGFloat.self) { $0.size.width.rounded() } action: { width in
            // Only a settled width. The column animates open and shut, and the frames in between
            // are narrower than the pane may ever be: the last one published on a launch was 112
            // points against a settled 380, which put the rule in the title bar 20 points to the
            // right of the divider under it. Below the minimum is a frame of an animation rather
            // than a width, and the last real one still holds.
            guard width >= Metrics.inspectorMinimum else { return }
            InspectorGeometry.shared.setInspectorWidth(width)
        }
        // And nothing at all once the pane is gone, so the rule goes with it.
        .onDisappear { InspectorGeometry.shared.setInspectorWidth(0) }
        // Once, here, rather than a repository id threaded through every row of two lists that
        // have no other use for one. See `EnvironmentValues.openInRepoID`.
        .environment(\.openInRepoID, model.repo?.id)
    }

    @ViewBuilder
    private var content: some View {
        switch model.inspectorTab {
        case .allFiles:
            FileTreeView(model: model)
        case .changes:
            ChangedFileList(model: model)
        case .checks:
            ChecksView(model: model)
        }
    }
}

/// What `gh` said when the last refresh failed: one sentence, with the command's own transcript
/// folded away behind it.
///
/// **The whole row opens it, not the triangle alone.** A `DisclosureGroup` toggles from its
/// triangle and from nothing else, so the sentence beside it looked pressable and was not. Driven
/// from state here instead, with the label a plain button across the full width, which is how
/// every other disclosure on this Mac behaves.
///
/// Three blocks rather than one paragraph. The first line of a `gh` failure says what went wrong;
/// what follows it is the command's usage text, flags and all, and eleven lines of terminal help
/// set as prose in a two hundred point column is a wall. The split is
/// `GitHubReadFailure.summary` and `.transcript`, in the core, where it is tested.
private struct RefreshFailureRow: View {
    var failure: GitHubReadFailure
    var hasPullRequest: Bool

    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: InspectorLayout.gap) {
                Text(failure.summary)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)

                if let transcript = failure.transcript {
                    // The command's own output, in the face it was written in and scrolling
                    // sideways rather than wrapping: a usage block wrapped at this width reads as
                    // a different command from the one that ran.
                    ScrollView(.horizontal) {
                        Text(transcript)
                            .font(Typo.codeSmall)
                            .foregroundStyle(Palette.textSecondary)
                            .textSelection(.enabled)
                    }
                    .frame(maxHeight: 140)
                    .padding(InspectorLayout.tight)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.surfaceRaised, in: .rect(cornerRadius: Metrics.cornerSmall))
                }

                if let retryAt = failure.retryAt {
                    Text("Next refresh after \(retryAt.formatted(date: .omitted, time: .shortened))")
                        .font(Typo.micro)
                        .foregroundStyle(Palette.textTertiary)
                }
            }
            .padding(.top, InspectorLayout.tight)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Button {
                isExpanded.toggle()
            } label: {
                Label(
                    hasPullRequest ? "Showing the last GitHub update" : "GitHub could not refresh",
                    systemImage: "exclamationmark.triangle"
                )
                .font(Typo.caption)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, InspectorLayout.inset)
        .padding(.vertical, Metrics.spacing)
        .accessibilityElement(children: .contain)
    }
}
