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
        "git branch",
        "git branch --show-current",
        "git branch --list 'fix/*'",
        "git branch --merged main",
        "git branch --list --format='%(refname:short)'",
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
        "gh pr view 374 --json number,title",
        "gh pr list --state open --json number",
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
        "tail -n 5 notes.txt",
        "head -n 20 Sources/Core/Agent/OrchestratorReadList.swift",
        "cat -n README.md",
        "ls -la Sources",
        "ls -l -a",
        "grep -rni --include='*.swift' Orchestrator Sources",
        "grep -e foo -- notes.txt",
        "wc -lw notes.txt",
        "pwd -P",
        "echo -n hi",
        "echo /tmp/x",
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
        "wc --libxo=encoder=../../tmp/evil notes.txt",
        "ls --libxo json",
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
        "git branch 12>/dev/null",
        "git tag 12>/dev/null",
        "ls 12>/dev/null",
    ])
    func redirectionsAreCaught(_ command: String) {
        #expect(!OrchestratorShellJudge.reads(command))
    }

    @Test("a descriptor after >& is digits or a lone dash, since zsh writes a file for anything else", arguments: [
        "ls >&-3",
        "ls >&3-",
        "ls 2>&1-",
        "ls >&--",
        "ls >&-1-",
    ])
    func duplicatedDescriptorsAreDigits(_ command: String) {
        #expect(!OrchestratorShellJudge.reads(command))
    }

    @Test("a closed descriptor and a duplicated one are still reads", arguments: [
        "ls >&-",
        "ls 2>&-",
        "ls 2>&1",
    ])
    func plainDescriptorsRead(_ command: String) {
        #expect(OrchestratorShellJudge.reads(command))
    }

    @Test("a word the shell expands into the environment or a path is asked", arguments: [
        "echo ~",
        "echo ~root",
        "ls ~/.ssh",
        "echo --x=~/y",
        "echo a:~/y",
        "ls =ls",
        "echo =zsh",
    ])
    func expansionsAreAsked(_ command: String) {
        #expect(!OrchestratorShellJudge.reads(command))
    }

    @Test("a filter that can read the environment, or text sent to GitHub's search, is asked", arguments: [
        "gh pr list --json number --jq '$ENV.HOME'",
        "gh pr list --json number --jq 'env.HOME'",
        "gh pr list --json number -q 'env'",
        "gh pr list --json number --jq=env",
        "gh pr list --json number --template '{{.}}'",
        "gh pr list --json number -t '{{.}}'",
        "gh issue list --search=notes",
        "gh issue list --search notes",
        "gh issue list -S notes",
        "gh pr list --search orchestrator",
    ])
    func filtersAndSearchesAreAsked(_ command: String) {
        #expect(!OrchestratorShellJudge.reads(command))
    }

    @Test("a plain read names only paths inside the worktree", arguments: [
        "cat /etc/hosts",
        "cat ../other/notes.txt",
        "cat Sources/../../other/notes.txt",
        "cat ..",
        "head /Users/kid/.zshrc",
        "grep -rn token /Users",
        "ls /",
        "wc -l ../notes.txt",
        "tail -- /etc/hosts",
    ])
    func pathsStayInTheWorktree(_ command: String) {
        #expect(!OrchestratorShellJudge.reads(command))
        #expect(!OrchestratorShellJudge.refuses(command))
    }

    @Test("a git read names only paths inside the worktree, since git leaves it by itself for one outside", arguments: [
        "git diff /etc/hosts Package.swift",
        "git diff Package.swift ../other/.env",
        "git diff --stat -- /etc/hosts",
        "git log -- ../other",
        "git blame /etc/hosts",
    ])
    func gitPathsStayInTheWorktree(_ command: String) {
        #expect(!OrchestratorShellJudge.reads(command))
        #expect(!OrchestratorShellJudge.refuses(command))
    }

    @Test("a gh read that waits on a run, and holds the call while it runs, is asked", arguments: [
        "gh run watch 42",
        "gh run watch 42 --exit-status",
        "gh pr checks 374 --watch",
        "gh pr checks 374 --watch --interval 5",
        "gh pr checks 374 -i 5",
    ])
    func ghWaitsAreAsked(_ command: String) {
        #expect(!OrchestratorShellJudge.reads(command))
        #expect(!OrchestratorShellJudge.refuses(command))
    }

    @Test("a plain read takes only the flags its list names", arguments: [
        "tail -f notes.txt",
        "tail -F notes.txt",
        "tail -n 5 -f notes.txt",
        "tail -5f notes.txt",
        "cat --unknown notes.txt",
        "ls -Z",
        "ls -laZ",
        "grep -f patterns.txt notes.txt",
        "grep -rnf patterns.txt notes.txt",
        "grep --file=patterns.txt notes.txt",
        "head -n5 notes.txt",
        "wc -x notes.txt",
        "pwd Sources",
        "echo -e x",
    ])
    func unknownFlagsAreAsked(_ command: String) {
        #expect(!OrchestratorShellJudge.reads(command))
        #expect(!OrchestratorShellJudge.refuses(command))
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
        "git stash list",
        "git stash show -p",
        "git apply fix.patch",
        "git apply",
        "git apply --check fix.patch",
        "git apply fix.patch -- --stat",
        "git branch --format --list new",
        "git branch --sort --list new",
        "git branch -- --list new",
        "git tag --format --list v9",
        "git tag --sort --list v9",
        "git tag -- --list v9",
        "git log -- --output=notes.txt",
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
        "gh issue list --repo evil.example/o/secret",
        "gh issue list --repo=evil.example/o/secret",
        "gh issue list -R evil.example/o/secret",
        "gh pr view https://evil.example/o/r/pull/1",
        "gh run view https://evil.example/o/r/actions/runs/1",
        "gh repo view evil.example/o/r",
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
        "git apply --check fix.patch",
        "git stash list",
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
}
