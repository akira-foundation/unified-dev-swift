import Foundation

public enum MergeInstructions {
    public static let canonical = """
    This message names the pull request, the branch it is on, and the merge method to use. Nothing
    below chooses any of those, and nothing below may change them.

    - If this project has a skill or an instruction file about merging, follow that first. It
      outranks everything here.
    - Merge with `gh pr merge <number> <method flag>`, run from this worktree, where the method
      flag is the one the message names: `--squash`, `--merge` or `--rebase`.
    - Pass no other flags.
      Not `--admin`, which overrides the repository's own rules.
      Not `--auto`, which merges later, when nobody is watching.
      Not `--delete-branch`, which makes gh reach for this checkout and fail, because a worktree
      cannot check out the branch the main copy is standing on.
    - **If GitHub refuses the merge because the branch conflicts with the base branch, or because
      a required check failed, resolve it and merge again.** These are the two refusals the branch
      itself can answer, and the person who pressed the button wants the merge, not a report.
      - A conflict: fetch the base branch, bring it into this branch the way this project brings
        it in (merge it unless the project's own conventions say to rebase onto it), work through
        every conflicted file keeping what both sides changed, and run whatever this project uses
        to check itself.
      - A failed check: read why with `gh pr checks <number>` and `gh run view <run id>
        --log-failed`, fix the cause in this worktree, and run the same check here when the
        project has a way to.
      - Commit the fix, worded the way this project words a commit, and push it to this branch
        and no other. If bringing the base in rewrote this branch's commits, the push needs
        `--force-with-lease`.
      - Wait for the checks on the new head with `gh pr checks <number> --watch`, then run the
        same `gh pr merge` again.
      - **Three rounds at most.** A round is one fix, one push and one merge attempt. If the third
        is refused too, stop and say what GitHub said each time.
    - **Any other refusal, stop.** A review that is required, a permission, a branch protection
      rule, anything that is not a conflict or a failed check: say what GitHub said, in its own
      words. Do not force it, and do not change a branch protection rule, a required check, a
      review or any other repository setting to get round it. A refusal of that kind is an answer.
    - **Stop rather than guess.** If this worktree already held work GitHub has not got before you
      started, uncommitted or committed and not pushed, a push would carry it out with the fix, so
      do not resolve anything: say the refusal and that the work is there. Stop as well if a
      conflict genuinely could be resolved either way or a check fails for a reason neither branch
      explains, and say what you are unsure about. A resolution nobody believes in is worse on the
      server than in a worktree.
    - Only once the merge has actually succeeded, delete the branch on the server with
      `git push --delete -- origin refs/heads/<branch>`, using the branch the message names. If
      git answers that the remote ref does not exist, the repository deleted it on merge and there
      is nothing left to do. This is a separate command from the merge and it runs second, never
      instead.
    - Leave the worktree where it is. Do not delete the local branch, do not remove or move the
      worktree, and do not check out anything else. This worktree stays where it is, on the branch
      it is on, and Unified Dev archives it separately when the person asks.
    - Commit and push nothing but the resolution of a refusal. Work GitHub has not got was the
      reader's decision before pressing the button, not a thing to fix. If the merge went through
      with such work still here, say in one line that it was left behind.
    - Finish by saying what happened: that it merged, what you fixed on the way and in how many
      rounds, and whether the branch on the server is gone.

    If a step fails, stop and say what went wrong instead of working around it.
    """
}
