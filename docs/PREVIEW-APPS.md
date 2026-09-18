# Preview apps, one per worktree

Every worktree can build its own copy of Unified Dev, with its own identity, its own database and
its own test state, and several of them can be open at once beside the real app and the dev copy.
This is what a pull request is shown with.

    make preview                                  build this worktree's preview
    ./Tools/dev-build.sh --preview --label "..."  the same, naming it in every window title
    open "$PWD/.build/preview/UD #31.app" --args --scenario "$PWD/Tools/scenarios/harbour.json"
    make preview-clean                            remove it and everything it made

## What a preview is

`Tools/dev-build.sh --preview` is a fast build of the worktree's current files, with the identity
applied to the finished bundle rather than to the sources. The identity is derived in
`Sources/Core/Preview/PreviewIdentity.swift` and printed for the script by the `preview` executable,
so the rule is tested in `Tests/CoreTests/PreviewIdentityTests.swift` rather than repeated in shell.

| | Derived from | Example, for `.claude/worktrees/worktree-preview-apps` on `feat/31-...` |
| --- | --- | --- |
| Bundle id | the worktree's folder name | `io.akira.unifieddev.dev.worktree-preview-apps` |
| Dock and Cmd-Tab name | the issue number at the head of the branch | `UD #31` |
| Window title | the label passed with `--label`, else the branch | `[DEV · Preview apps per worktree] Lighthouse` |
| URL scheme | the slug | `unifieddevdev-worktree-preview-apps` |
| Services menu item | the Dock name | `New UD #31 Workspace` |
| Bundle | the worktree | `.build/preview/UD #31.app` |
| Database | the worktree | `.build/preview/data/unifieddev.sqlite` |
| Workspaces root | the worktree | `.build/preview/workspaces` |
| Scratch repositories | the worktree | `.build/preview/scratch` |

The tmux socket, the bridge socket and the bridge token all derive from the database path, so they
separate with it. Preferences, saved window state, notifications and WebKit data derive from the
bundle id. `.build/preview/identity.env` records the identity the bundle was given, which is what
`make preview-clean` reads back.

With no issue number in the branch the Dock name falls back to `UD <slug>`. A label is cut to forty
characters, so the workspace name still shows in the title. `--label` works for the dev copy too,
and goes through the same rule.

The slug is the worktree folder's name, so two checkouts of this repository in folders of the same
name would share a bundle id. Worktrees live under one `.claude/worktrees/`, where a name is unique.

### Two agreeing paths to every location

The database, the workspaces root and the preview root are written twice into `Info.plist`: under
`LSEnvironment`, which LaunchServices hands to a process it opens, and as top-level keys of the same
names. `LaunchOverride` reads the bundle's own key first and the environment only when the bundle has
none. Two cases decide that order. An executable run by hand gets no `LSEnvironment`, and without
the key it would fall back to the owner's real `~/unifieddev/workspaces.noindex` for new worktrees.
And a preview started from a terminal pane of the dev copy inherits that pane's `UD_DB_PATH`; if the
environment won, the preview would open the dev copy's database.

The real app declares none of these keys, and never takes its workspaces root from the environment
at all (`WorkspacesRoot.overrideValue`), so nothing an agent exports can move where it cuts
worktrees.

### The title is read at run time

The window title used to be marked by rewriting three Swift lines in the staged sources. It is now
one Info.plist key, `UDWindowTitlePrefix`, read by `WindowTitleMark`. The real app has no such key
and shows no mark. The dev copy and the subagents copy set it to `[DEV] ` and `[SUB] `, and a
preview to its label. Nothing in the sources changes between a dev build and a preview, so both
share the fast build cache of their worktree without recompiling anything.

## The scenario

A scenario is a JSON file describing the state a test needs. This is a shortened
`Tools/scenarios/harbour.json`:

```json
{
  "welcome": false,
  "projects": [
    {
      "name": "harbour",
      "files": { "src/pier.txt": "wood\n" },
      "commits": ["Lay the pier", "Paint the boats"],
      "remoteAhead": ["Light the lighthouse", "Ring the bell"],
      "workspaces": [
        { "name": "Lighthouse", "branch": "lighthouse",
          "chats": [{ "title": "Plan", "messages": [
            { "from": "user", "text": "Is the lamp lit?" },
            { "from": "agent", "text": "Not yet." }] }] },
        { "name": "Bell", "branch": "bell" }
      ]
    }
  ]
}
```

| Field | Meaning |
| --- | --- |
| `welcome` | `false` marks onboarding complete, so the welcome window does not open. Default `true`. |
| `projects[].name` | the folder name of a scratch repository; letters, digits, `-`, `_` and `.` |
| `files` | written before the first commit, as paths inside the project |
| `commits` | the project's own history on `main`, pushed to its remote |
| `remoteAhead` | commits pushed to the remote from another clone and never fetched here |
| `branches` | branches cut from `main` with one commit each, pushed to the remote and left in the clone, open in no workspace |
| `workspaces` | cut through `WorkspaceManager.start`, as the app does, with setup skipped |
| `remote` | how the remote answers a fetch once seeding is done: `promptly` (default), `slowly`, eight seconds late, or `never` |
| `chats` | sessions in that workspace, each a list of `user` and `agent` lines |

`--scenario <file>` at launch reads it. `PreviewScenarioLaunch` reads and validates it before any
window opens, then `AppModel.bootstrap` seeds it through `PreviewScenarioSeeder` in the core, once
the store is open and before the sidebar loads. Every repository is made with the app's own `Git`,
every row with its own `Store` and `WorkspaceManager`: no SQL is written by hand. Each project gets a
bare remote under `scratch/remotes` and a clone under `scratch/projects`, committed with a fixed
scratch author and with signing and hooks turned off, so the owner's own git configuration never
touches a scratch commit.

It refuses, and creates nothing, when:

- the process is not a preview: the bundle id must be `io.akira.unifieddev.dev.<slug>`, and the
  database and workspaces root must both lie inside the preview root (`PreviewLaunch.root`). The real
  app and the dev copy can be given `--scenario` and do nothing but say so;
- the path is relative: an app opened with `open` starts in `/`, so the scenario is always given as
  an absolute path;
- the scenario is invalid: a project name with a slash, a file path leaving the project or naming
  `.git` in any case, a branch git would refuse, `main` as a workspace branch, a branch nested under
  another (`ui` and `ui/panel`), or a name used twice;
- the preview already holds a project. A scenario seeds an empty preview once; launching again
  with the same argument leaves the state the tester has made since. `make preview-clean` starts
  over.

A failure part way through, a push refused for instance, leaves what was made so far and says so
in an alert; the next launch sees projects and seeds nothing more. `make preview-clean`, a new build
and a new launch are the way back.

`open` passes `--args` only to an app it is launching, so quit the preview before opening it again
with a scenario. Do not add `-n`: it starts a second instance of the same preview on the same
database.

## One build at a time, any number open

Compiling is what the machine cannot afford twice. `Tools/dev-build.sh` takes a reservation in the
main checkout's `.claude/preview.lock`, in every one of its modes. A fast build or a preview releases
it once compiled; a release build holds it to the end, because it shares `/tmp/unifieddev-dev-src`
and `/tmp/unifieddev-dev-build` with every other release build. The file names the pid, the
worktree, the branch and the start time. A reservation whose pid has gone is taken over, by moving
it aside and checking it is still the one that was read; one written by hand with no pid is left
alone and reported, because the rule before this one was a reservation held until the owner had
finished looking. `subagents-build.sh`, `master.sh` and `make app` do not take it.

Opening needs no reservation. Every preview open with agents running adds its processes to the
machine, so say so when handing over a second or third.

## Cleaning up

`make preview-clean` quits the preview if it is running, kills its tmux server by socket name,
removes its bridge socket, unregisters the bundle from LaunchServices, deletes its preferences
domain, its saved window state, caches, HTTP storage, WebKit data and fallback Application Support
folder, removes `.build/preview` (the bundle, the database, the scratch repositories and every
workspace the scenario or the tester cut there) and the worktree's fast build cache under
`/tmp/unifieddev-dev-fast-<hash>`.

Every path it removes is either inside `.build/preview` of the worktree it runs in, or under
`~/Library` named by a bundle id that `ud_refuse_unless_preview` has already checked is a preview
identity. It refuses to run from inside the preview it would remove, and it refuses an `identity.env` whose
bundle id was not derived from this worktree's name or whose bridge server name is not the one that
bundle id gives, so a stale or edited file cannot point it at another preview or at the real app's
registration.

## Decisions, and what they were measured against

### The user-level bridge registration

`BridgeRegistration.ownerServerName` names the entry in `~/.claude.json` after the bundle id, so the
real app's is `unified-dev`, the dev copy's `unified-dev-dev`, and a preview's
`unified-dev-io-akira-unifieddev-dev-<slug>`. On the owner's Mac on 18 September 2026 the top-level
`mcpServers` table held none of them.

The app never writes a registration on its own. The only write is
`BridgeUserRegistrationRepair`, which rewrites an entry under this copy's own name, carrying this
copy's own socket and token, whose shim has moved. A preview therefore cannot rewrite the real
app's entry or another preview's: different name, and a socket and token no other copy can mint.
`Tests/CoreTests/BridgeUserRegistrationRepairTests.swift` holds that with two previews and the real
app in one file.

So several previews do not fight over the registration, and none can point the owner's `claude`
at itself unless the owner pastes the command a preview offers. If that happens, the entry is
under the preview's own name and `make preview-clean` removes it from Claude Code, Codex and Grok,
because a registration whose shim has been deleted fails in every session that loads it.

### The URL scheme

LaunchServices binds a scheme to whichever registered bundle it prefers, and on the owner's Mac
`unifieddevdev` was bound to the dev copy alone. Every preview sharing it would have let a link meant
for the dev copy open in whichever preview registered last. Each preview gets
`unifieddevdev-<slug>`; `DeepLink` accepts whatever schemes its own bundle declares, so nothing in the
app changed for it. The Services menu entry and its port name are per preview for the same reason.

### Keeping the real app and data out of reach

`Tools/guard.sh` gained `ud_refuse_unless_preview`, run on the identity before anything is
installed and before anything is removed. It refuses a bundle id that is not
`io.akira.unifieddev.dev.` followed by a lowercase slug, which excludes the real, dev and subagents
ids by construction; a root other than this worktree's `.build/preview`; a bundle, database,
workspaces root or scratch root outside that root or climbing out of it with `..`; and a database
inside the real, dev or subagents Application Support folders. `ud_refuse_real_app`,
`ud_refuse_real_db` and `ud_refuse_if_own_host` still run on top of it.

### The third identity

`Unified Dev Subagents` stays as it is, a fixed identity installed to `~/Applications`. A preview
generalises it: the same separation, derived per worktree instead of written into a script, and
living inside the worktree instead of beside the owner's apps.

---

[Architecture](ARCHITECTURE.md) · [Bridge](BRIDGE.md) · [Agents integration](AGENTS-INTEGRATION.md)
