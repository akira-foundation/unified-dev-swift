# Profiles

A profile is a named group of projects. The window shows one profile at a time: its projects, their
workspaces, Home and the archive. Someone who works for several organisations keeps each in its own
profile and switches between them without the others in the way.

Every profile has a name, a colour, a symbol, a position in the list and a folder. The first one,
Unified, exists from the start, has the fixed id `unified`, and cannot be deleted. Every project
belongs to exactly one profile. A database that predates profiles has every project in Unified.

## Folders

A workspace is a worktree on disk, and a profile gives its worktrees a folder of their own:

    <workspaces root>/<profile folder>/<project>/<branch>

The folder is derived from the profile's name when the profile is created and never changes
afterwards, so renaming a profile does not move anything. Accents and case are folded and anything
that is not a letter or a digit becomes a dash, so "Débtges" gives `debtges`. Two names that fold to
the same folder get different ones, the second ending in `-2`. `ProfileFolder` decides it.

The initial profile's folder is `unified`: its new worktrees are created under `unified/`. Worktrees
that already existed before profiles are never moved and stay where they were.

## Accounts

Every agent account belongs to one profile. Settings, Agents lists the accounts of the active
profile, and an account added there belongs to it, or to Unified when the active profile uses
Unified's. Profile Settings signs in to an account of the profile it is editing, whichever
profile the window shows, and a profile that has just taken accounts of its own, new or switched,
stays open after Save to sign in to the first one. The id of an account stays global and carries its
provider, so the same login wanted in two profiles is two accounts, each signed in on its own.

A profile either has accounts of its own or uses the accounts of Unified, never both. It is chosen
when the profile is created, and changed in Profile Settings. A new profile uses Unified's until it
is told otherwise. Using Unified's means all of them and Unified's default, as they are now and as
they change, with nothing copied. Unified always has its own.

Each profile with accounts of its own has a default per CLI, chosen in Profile Settings among them.
The login this Mac already had, `~/.claude` and `~/.codex`, belongs to Unified.

Which account an agent runs under is decided in this order:

1. the account chosen for the project, among those of its profile;
2. the default of the profile, or of Unified when the profile uses Unified's;
3. this Mac's own login, for Unified and for a profile that uses Unified's.

A profile with accounts of its own never takes the third step, for a CLI that has a default account
to fall back to. When neither the project nor the profile names an account for the CLI that is still
there, the turn does not start: the chat says why and asks for an account, and the composer and
Settings show the account as unavailable before anything is sent. A CLI that has no default account
at all is the exception, and Grok is the one today: there is nothing to refuse the fall back to, so
the turn runs under this Mac's own login in every profile, and Settings says so rather than
promising a refusal that would not happen. The work of one organisation therefore
cannot run, or be billed, under the login of another. A project of such a profile that holds a
choice of this Mac's own login, made on purpose, runs it. `ProfileAccounts` decides what a profile
holds, lists and reaches, and `AgentAccountLaunch` decides whether a choice may start an agent at all.

An Ask chat has no project, so it skips the first step and runs the default of the profile its turn
is pinned to, which is the active profile when the turn starts (see [The bridge](#the-bridge)). Its
composer has no Account row, because there is no project whose choice it could change.
`AccountScope.chat` decides which scope a chat's turns run under.

Changing a profile's default does not stop a turn. The chat moves to the new account on its next
send, with the notice and the divider of [CHAT-SEGMENTS.md](CHAT-SEGMENTS.md). A CLI already running
in a terminal pane keeps the account it was started with until the pane is closed.

### When something moves

A project moved to another profile keeps no choice of an account its new profile does not hold: the
choice is cleared, the project runs the new profile's default, and a notice names what changed. A
profile that switches between its own accounts and Unified's clears the same way, for every project
in it, and switching back does not bring those choices back. While a profile uses Unified's, the
accounts it owns are listed nowhere and wait for it to have its own again. Deleting a profile, which
by then has no projects, gives its accounts back to Unified.

Removing an account is refused while an agent runs under it, counting the agents that reach it as
their profile's default as well as those whose project chose it. The confirmation names the projects
that chose it; they go back to their profile's default, and in a profile with accounts of its own and
no default for that CLI they do not start until another is chosen.

### A database from before

The migration is additive. Each existing account goes to the profile whose projects chose it, and to
Unified when no project chose it or projects of more than one profile did. A profile that receives
no account uses Unified's, so its agents run exactly as they did; one that receives an account has
accounts of its own. A project of such a profile that chose an account left with Unified, because
another profile's projects chose it too, loses that choice and runs its profile's default, with the
warning the composer shows for a lost choice, or does not start until an account is chosen when the
profile has no default for that CLI.

### Spend and quotas

The spend screen shows the active profile: the turns run in its projects, and the lines of its
accounts and of this Mac's own login. Turns run outside every project are Unified's. The quotas in the menu bar panel are those
of the account the active profile runs, for the selected workspace or, on Home, for the profile's
default.

## Moving a project

Project menu, Move to Profile, in the sidebar and on Home. Only the project's row changes. Its
existing worktrees stay on disk exactly where they are, and the workspaces keep working. A workspace
created afterwards is placed under the folder of the profile the project is in then, so after moving
a project into Debtges its next workspace is created under `debtges/`.

A profile that still holds projects cannot be deleted: the projects are moved first. What a move
does to the project's account is under [Accounts](#accounts).

A moved project's agents keep running, but they now belong to the new profile. `workspace_say` and
`workspace_archive` no longer reach their siblings in other projects of the old profile, in either
direction. A `notify_when_done` asked for before the move still arrives.

## Switching

The switcher sits at the top of the sidebar. With the sidebar hidden, the window shows the active
profile's mark in the toolbar instead. That mark has no menu: switch through the Profile menu or the
shortcut. The Profile menu lists the profiles, with New Profile and Profile Settings.

| Key | Action |
| --- | --- |
| `⌃⌘1` to `⌃⌘9` | Switch to the profile at that position |

The search palette reaches them too: from two typed letters, under Everything, it lists the profiles
whose name matches, best match first, and picking one switches to it. The section comes before the
workspaces when its best match is at least as good as theirs. The active profile is not listed, and
the workspaces and transcripts it finds stay those of the active profile. `SearchPanelProfiles` decides it.

`⌘` and a digit stays with the tabs. The active profile is stored and restored at launch, and each
profile remembers its last workspace. A stored active profile that no longer exists opens Unified, on
Unified's remembered workspace, or on Home when it has none. A remembered workspace that was archived
lands on the active profile's Home.

Switching changes what is shown and nothing else. It does not stop, close or restart any agent or
terminal. An agent working in a profile that is not on screen keeps working, still counts towards
keeping the Mac awake, and a notification from it names its profile so it is clear where it came
from.

## The bridge

An agent calling back in through the bridge sees only its own profile: the projects, workspaces and
chats of the profile its workspace belongs to. The owner's client sees the active profile. An Ask chat
is pinned to the profile active when its turn starts, for that turn, so switching mid turn does not move
what it is doing. While that turn belongs to a profile the window is not showing, `reveal` is refused,
names the profile, and leaves the window where it is. Anything in another profile is answered as if it did not exist, unless the caller may reach it. `workspace_start` and
`project_add` name the profile they landed in. The scope and its exceptions are in
[BRIDGE.md](BRIDGE.md), under "The profile a caller is limited to".

### Connected to other profiles

Profile Settings carries a switch, **Connected to other profiles**, off by default. Turned on, a
project's orchestrator can list that profile's projects and workspaces, read its chats and changes, and
send a message to one of its chats, if its own profile is on too, and the owner approves every such call.
The owner's Ask chat and client need only the destination on, and do not stop to ask. Ordinary workspaces,
subagents and an orchestrator on Codex never cross, and nothing can be started in another profile.

Every crossing names the profile, through a `profile` argument, or `all` on the two lists. A message
from another profile says where it came from and does not carry the owner's authority, whoever sent it. The
turn it wakes runs on the destination project's account. A chat cannot be answered across profiles except by
a caller that may cross, so what comes back to anyone else is the end of that turn, if `notify_when_done`
asked for it. [BRIDGE.md](BRIDGE.md) has the rules, under "Reaching another profile".

## In a preview scenario

A scenario may declare `profiles` (`name`, `colour` as a hex string without `#`, `symbol`, and
`accounts` as `own` or `inherits`), name one for a project with `profile`, and open on one with
`activeProfile`. A labelled account that names a `profile` is added to it, and `isProfileDefault` makes
it that profile's default; a labelled account that names none belongs to Unified, and the one with no
label is this Mac's own login, which cannot name a profile. A project that names no profile
is in Unified. `reachableProfiles` names the profiles to open to the others, and
`Tools/scenarios/profiles-reach.json` seeds an orchestrator in Unified with Akira open and Debtges closed.
`Tools/scenarios/profiles.json` seeds Unified, Akira and Debtges with two projects
each, Akira with two Claude Code accounts and a Codex one of its own and Debtges using Unified's. See [PREVIEW-APPS.md](PREVIEW-APPS.md).

## Not there yet

- The oceans chart is global: it shows every profile's.
- GitHub accounts per profile.
- Moving a project's existing worktrees into its new profile's folder.
