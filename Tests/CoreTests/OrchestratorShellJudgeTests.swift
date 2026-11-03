import Foundation
import Testing
@testable import Core

@Suite("Orchestrator shell judge")
struct OrchestratorShellJudgeTests {
    @Test("the forms an orchestrator reads with every day are on the list", arguments: [
        "git log",
        "git log --oneline -5",
        "git log --format='%h > %s'",
        "git --no-pager log -n 3",
        "git diff",
        "git diff main...HEAD",
        "git diff --stat HEAD~1 -- Sources",
        "git status",
        "git status -sb",
        "git show HEAD",
        "git show --stat HEAD~2",
        "git stash list",
        "git stash show -p",
        "git apply --check fix.patch",
        "git branch",
        "git branch --show-current",
        "git branch --list 'fix/*'",
        "git branch --merged main",
        "git tag",
        "git tag --list",
        "git tag --contains HEAD",
        "git tag --points-at HEAD",
        "git tag --merged main",
        "git worktree list",
        "git remote -v",
        "git rev-parse --abbrev-ref HEAD",
        "git merge-base main HEAD",
        "git blame -L 10,20 README.md",
        "git grep -n Orchestrator",
        "gh pr view 374",
        "gh pr view 374 --json number --jq '.number'",
        "gh pr list --search orchestrator",
        "gh pr list --json number --jq '.[] | select(.number > 1)'",
        "gh pr checks 374",
        "gh pr diff 374",
        "gh issue view 326",
        "gh issue view 326 --comments",
        "gh issue list --state open --limit 20",
        "gh run list --branch develop --limit 5",
        "gh run view 42 --log-failed",
        "ls",
        "ls -la 2>/dev/null",
        "cat README.md",
        "grep -rn Orchestrator Sources",
        "grep -rn Orchestrator Sources 2>&1 | head",
        "grep \"a\\|b\" notes.txt | wc -l",
        "tail -5 notes.txt",
        "pwd",
        "echo \"a && git commit\"",
        "echo \"\\\"\"",
        "ls 1>&2",
        "ls > /dev/null",
        "git status && git log -1; ls",
    ])
    func readsAreOnTheList(_ command: String) {
        #expect(OrchestratorShellJudge.reads(command))
        #expect(!OrchestratorShellJudge.refuses(command))
    }

    @Test("what the issue measured is no longer taken for reading", arguments: [
        "echo \"\\\"\" > notes.txt",
        "echo \"\\\"\" && rm -rf Sources",
        "echo hi >&notes.txt",
        "sed -Ei 's/a/b/' notes.txt",
        "find . -name x -delete",
        "python3 -c 'open(\"x\", \"w\")'",
    ])
    func measuredCasesAskTheOwner(_ command: String) {
        #expect(!OrchestratorShellJudge.reads(command))
        #expect(!OrchestratorShellJudge.refuses(command))
    }

    @Test("a command off the list is asked, whatever it does", arguments: [
        "rm -rf build",
        "mv a b",
        "touch file",
        "sed -n 1,5p notes.txt",
        "sed 's/a/b/w out.txt' notes.txt",
        "find . -name x",
        "find . -exec rm {} ;",
        "awk '$3 > 100' data.txt",
        "perl -e 'print 1'",
        "make",
        "curl -O https://example.com/x",
        "xargs rm",
        "tee out.txt",
        "sort -o out.txt in.txt",
        "cd /tmp",
        "env ls",
        "command ls",
        "exec ls",
        "/bin/ls",
        "./ls",
        "/tmp/evil/cat notes.txt",
        "FOO=1 ls",
        "GIT_EXTERNAL_DIFF=./evil git diff",
    ])
    func offTheListIsAsked(_ command: String) {
        #expect(!OrchestratorShellJudge.reads(command))
        #expect(!OrchestratorShellJudge.refuses(command))
    }

    @Test("a redirection cannot hide inside a listed command", arguments: [
        "echo hi > notes.txt",
        "echo hi >notes.txt",
        "cat a >> b",
        "ls 2> log.txt",
        "ls 2>> log.txt",
        "ls &> log.txt",
        "ls &>> log.txt",
        "ls >| log.txt",
        "ls >! log.txt",
        "ls >& log.txt",
        "ls 2>&notes.txt",
        "ls >&2x",
        "ls <> log.txt",
        "ls >",
        "ls > /dev/null > notes.txt",
        "ls >/dev/null.txt",
        "ls > '/dev/null/../../tmp/x'",
        "cat < notes.txt",
        "cat <<EOF",
        "cat <(rm x)",
        "ls >$OUT",
        "ls > \"$OUT\"",
    ])
    func redirectionsAreCaught(_ command: String) {
        #expect(!OrchestratorShellJudge.reads(command))
    }

    @Test("chains, subshells and scripts are read clause by clause, or not at all", arguments: [
        "ls && rm x",
        "ls || rm x",
        "ls ; rm x",
        "ls\nrm x",
        "ls\r\nrm x",
        "ls | xargs rm",
        "ls | sh",
        "ls |& tee x",
        "ls & rm x",
        "ls &",
        "(ls)",
        "(rm x)",
        "{ ls; }",
        "ls $(rm x)",
        "ls `rm x`",
        "echo \"$(rm x)\"",
        "echo \"`rm x`\"",
        "echo $HOME",
        "echo ${HOME}",
        "sh -c 'ls'",
        "sh -c 'rm x'",
        "bash -lc 'ls > x'",
        "zsh -c \"rm x\"",
        "eval ls",
    ])
    func chainsAreCaught(_ command: String) {
        #expect(!OrchestratorShellJudge.reads(command))
    }

    @Test("the shell would read these differently from a word by word reading", arguments: [
        "ls \"unterminated",
        "ls 'unterminated",
        "ls # ' \n rm x # '",
        "ls \\\nrm x",
        "\\rm x",
        "ls\u{A0}&&\u{A0}rm x",
        "ls >\u{0301} notes.txt",
        "ls *",
        "git diff *",
        "cat ?.txt",
        "cat [a].txt",
        "cat {a,b}",
        "cat !x",
        "cat $'a'",
        "",
        "   ",
    ])
    func trickyQuotingAsks(_ command: String) {
        #expect(!OrchestratorShellJudge.reads(command))
    }

    @Test("git and gh are lists of verbs, never the whole command", arguments: [
        "git",
        "git fetch",
        "git fsck",
        "git config user.name x",
        "git gc",
        "git update-ref -d refs/heads/x",
        "git push",
        "git -C /tmp/w log",
        "git -c core.pager='rm x' log",
        "git -c alias.log='!rm x' log",
        "git --exec-path=. log",
        "git --git-dir=/tmp/x log",
        "git log --output=notes.txt",
        "git log --outp=notes.txt",
        "git diff --output=notes.txt",
        "git diff --ext-diff",
        "git show --output=notes.txt",
        "git stash",
        "git stash push",
        "git stash drop",
        "git stash list --output=notes.txt",
        "git apply fix.patch",
        "git apply",
        "git apply --check --index fix.patch",
        "git branch new",
        "git branch -D old",
        "git branch -m old new",
        "git branch -a new",
        "git tag v1",
        "git tag -d v1",
        "git tag --sort=refname v9",
        "git worktree",
        "git worktree add ../x",
        "git worktree prune",
        "git remote add x y",
        "git grep -O./evil x",
        "gh",
        "gh pr",
        "gh pr merge 374",
        "gh pr create",
        "gh pr close 374",
        "gh pr comment 374 -b x",
        "gh pr view 374 --web",
        "gh pr view 374 -w",
        "gh issue create",
        "gh issue close 1",
        "gh issue view 1 -w",
        "gh run rerun 42",
        "gh run cancel 42",
        "gh run download 42",
        "gh api repos/x/y",
        "gh api -X DELETE repos/x/y",
        "gh release create v1",
        "gh repo delete x",
        "gh extension install x",
        "gh alias set x y",
    ])
    func verbsAndFormsAreClosed(_ command: String) {
        #expect(!OrchestratorShellJudge.reads(command))
    }

    @Test("a git verb that changes the repository is refused, wherever it is written", arguments: [
        "git commit -m 'x'",
        "git push origin main",
        "git pull",
        "git merge feat",
        "git rebase main",
        "git reset --hard",
        "git checkout -- Sources",
        "git switch main",
        "git restore Sources",
        "git stash",
        "git stash push",
        "git cherry-pick abc",
        "git revert abc",
        "git am fix.patch",
        "git apply fix.patch",
        "git add .",
        "git rm file",
        "git mv a b",
        "git clean -fd",
        "git -C /tmp/w push origin main",
        "cd /tmp && git merge feat",
        "FOO=1 git commit -am x",
        "env git commit -am x",
        "/usr/bin/git commit -am x",
        "/bin/zsh -lc 'git commit -am x'",
        "bash -c \"git push\"",
        "(git commit -am x)",
        "git commit -m \"$(cat notes.txt)\"",
        "git log; git push",
    ])
    func gitWritesAreRefused(_ command: String) {
        #expect(OrchestratorShellJudge.refuses(command))
        #expect(!OrchestratorShellJudge.reads(command))
    }

    @Test("the read forms of a refused verb are not refused", arguments: [
        "git stash list", "git stash show", "git apply --stat fix.patch",
    ])
    func readFormsOfRefusedVerbs(_ command: String) {
        #expect(!OrchestratorShellJudge.refuses(command))
    }
}
