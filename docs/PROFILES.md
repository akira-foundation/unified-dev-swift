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

## Moving a project

Project menu, Move to Profile, in the sidebar and on Home. Only the project's row changes. Its
existing worktrees stay on disk exactly where they are, and the workspaces keep working. A workspace
created afterwards is placed under the folder of the profile the project is in then, so after moving
a project into Debtges its next workspace is created under `debtges/`.

A profile that still holds projects cannot be deleted: the projects are moved first.

## Switching

The switcher sits at the top of the sidebar, and stays there when the sidebar is hidden, in the
toolbar, with the active profile marked in the window. The Profile menu lists the profiles, with New
Profile and Profile Settings.

| Key | Action |
| --- | --- |
| `⌃⌘1` to `⌃⌘9` | Switch to the profile at that position |

`⌘` and a digit stays with the tabs. The active profile is stored and restored at launch. If it no
longer exists, or the remembered workspace was archived, the app opens on Unified, on Home.

Switching changes what is shown and nothing else. It does not stop, close or restart any agent or
terminal. An agent working in a profile that is not on screen keeps working, still counts towards
keeping the Mac awake, and a notification from it names its profile so it is clear where it came
from.

## The bridge

An agent calling back in through the bridge sees only its own profile: the projects, workspaces and
chats of the profile its workspace belongs to. The owner's client sees the active profile. Anything
in another profile is answered as if it did not exist. The scope and its exceptions are in
[BRIDGE.md](BRIDGE.md), under "The profile a caller is limited to".

## In a preview scenario

A scenario may declare `profiles` (`name`, `colour` as a hex string without `#`, `symbol`), name one
for a project with `profile`, and open on one with `activeProfile`. A project that names no profile
is in Unified. `Tools/scenarios/profiles.json` seeds Unified, Akira and Debtges with two projects
each. See [PREVIEW-APPS.md](PREVIEW-APPS.md).

## Not there yet

- Accounts per profile: which agent account a profile runs under is not part of profiles yet.
- Moving a project's existing worktrees into its new profile's folder.
