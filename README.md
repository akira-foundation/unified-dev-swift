# Unified Dev

A native macOS app for running coding agents in git worktrees.

Every piece of work gets a workspace, and a workspace is a real worktree on disk with its own
branch. One agent runs in it, in its own window region, with its own terminal and its own diff,
and nothing it does reaches the branch anybody else is on. Several run at once.

One window holds all of it: a sidebar of projects and their workspaces, the agent's transcript in
the centre, a terminal below it, and an inspector on the right with the diff, the files and the
pull request.

## What it runs

Claude Code, Codex, Grok, Cursor and OpenCode. The app finds the ones installed on the Mac and
asks for nothing to be typed in: [docs/AGENTS-INTEGRATION.md](docs/AGENTS-INTEGRATION.md) says how
each is detected and what it needs.

Each speaks its own protocol, and each is read rather than guessed at:
[docs/PROTOCOL.md](docs/PROTOCOL.md) for Claude Code's stream-json,
[docs/CODEX.md](docs/CODEX.md) for the Codex app-server protocol as measured, and
[docs/GROK.md](docs/GROK.md) for Grok's ACP over stdio.

An agent can also call back into the app it is running inside, through an MCP bridge, to open a
pane, read another workspace or ask for a review. [docs/BRIDGE.md](docs/BRIDGE.md) has the tools
and, more usefully, which callers may call what and why the line is drawn there.

## Requirements

macOS 26, and Xcode 26 for the toolchain. Swift 6.2, SwiftPM, language mode 6.

There is no Xcode project and that is deliberate, for reasons written out in
[CLAUDE.md](CLAUDE.md). Open `Package.swift` in Xcode and it builds, runs, debugs and previews.

## Building it

Everything real is a script in `Tools/`, and the `Makefile` is the index.

    make            list every target
    make build      compile every target, app included, the way CI does
    make test       run the Core suite
    make app        assemble a debug UnifiedDev.app
    make lint       the house rules no off the shelf linter knows
    make swiftlint  the rules SwiftLint knows, against .swiftlint.yml

Both linters have to pass, and they check different things. SwiftLint is not installed by
anything here: `brew install swiftlint`, or take the binary from its releases page.

## How it is laid out

Three targets, and one line between them that the linter holds.

`Sources/Core` is everything that is not a view: the store, git, the shell, the agent protocols,
the parsers, the models. It never imports a UI framework, which is what makes it testable.
`Sources/UnifiedDev` is the SwiftUI app and the only target allowed to import SwiftUI, AppKit or
SwiftTerm. `Sources/bridge` is the stdio shim an agent CLI launches as a child process, which
relays to the running app over a unix socket.

[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) goes further, and
[docs/PLAN.md](docs/PLAN.md) says what was built and in what order.

## Testing

`Tests/CoreTests` depends on `Core` alone, so a decision taken inside a view is a decision nothing
can test. `make test` mirrors the core sources into a throwaway package with no app target, so one
broken view cannot stop the suite.

A green suite does not prove the app compiles. Run `make build` as well.

## Developing it in itself

Unified Dev is developed in Unified Dev, which means the copy you are editing and the copy you are
running are different apps on purpose. `make dev` installs a second app with its own bundle id,
its own database and its own notifications, and `make preview` builds a worktree's own copy that
can reach neither. [docs/PREVIEW-APPS.md](docs/PREVIEW-APPS.md) has the rules and why they are
what they are.

[CLAUDE.md](CLAUDE.md) and [AGENTS.md](AGENTS.md) are the working agreement for anybody, human or
agent, changing this repository.

## Licence

GNU Affero General Public License v3. See [LICENSE](LICENSE), and
[LICENSE-THIRD-PARTY.md](LICENSE-THIRD-PARTY.md) for what is vendored.
