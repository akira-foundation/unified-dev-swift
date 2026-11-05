# The Claude Code stream-json protocol

Ground truth, captured from `claude` on this machine on 2026-08-18. A real capture lives at
`Tests/fixtures/session-basic.jsonl` (55 lines: thinking, two tool calls, two tool results, text,
result). Hook payloads in that file were trimmed because they were enormous, nothing else was
touched.

## How Unified Dev invokes it

```
claude
  -p
  --output-format stream-json
  --input-format stream-json
  --include-partial-messages
  --verbose
  --permission-mode <auto|acceptEdits|bypassPermissions|plan>
  --permission-prompt-tool stdio
  --model <opus|sonnet|haiku|...>
  [--effort <level>]                 only when the session has one
  [--thinking disabled]              fast mode, and only when it is on
  [--settings '{"outputStyle":"…"}'] only when a style was chosen
  [--mcp-config <path>]              the workspace bridge, a file and never inline JSON
  [--resume <agent session id>]
```

`--verbose` is required with `-p --output-format stream-json`, otherwise the CLI refuses to run.

`--permission-prompt-tool stdio` is undocumented, absent from `--help`, present in the binary, and
always on. Without it the CLI answers permission questions on the user's behalf and the answer is
no, which was every `permission-rule` refusal not made by a hook. It does not make the CLI ask
more: the classifier still approves what it approved before, measured at zero questions over seven
tool calls in one ordinary turn. The paragraph above `AgentRunner.argv` is where that measurement
lives, along with why `--settings` takes one object rather than accumulating and why the bridge is
handed over as a file (argv is visible in `ps`, and an agent runs `ps`).

Working directory is the worktree. Input is NDJSON on stdin, output NDJSON on stdout. stdin stays
open for the whole session so follow-up turns are just more lines.

### Sending a turn

One JSON object, one line:

```json
{"type":"user","message":{"role":"user","content":[{"type":"text","text":"do the thing"}]}}
```

### Sending into a turn that is already running

Measured on `claude 2.1.260` on 4 September 2026, driving the invocation above with a cheap model.
A second user line was written to stdin four seconds into a running turn. It was **accepted**: no
error, nothing lost, and the CLI did not close the pipe.

What it did with it depends on what the turn had left to do. The probe's turn was prose with no
tool call after the injection, and the CLI finished it, emitted its `result`, then emitted a
**second `init`** and ran the injected line as a turn of its own. The other landing is in the CLI's
own copy: a message whose origin is the person is framed as "The user sent a new message while you
were working", with a paragraph under it saying that is how Claude Code surfaces a mid-turn
message, within the running turn and often alongside the next tool result rather than as a separate
turn. So a turn with a tool boundary left in it takes the message inside the turn, and a turn
without one runs it next.

Both are landings Unified Dev already handles. `AgentRunner.ingest` applies `turnStarted` on an `init`,
which is the fix written for the CLI's habit of starting turns of its own (see `StrayResult`), so a
second `init` puts the chat back to running rather than leaving it drawn as idle through a turn.

`AgentKind.acceptsMidTurnMessage` is where this is written down as a fact the app reads, and
`DeliveryHold.allowsDelivery(on:)` is what it decides.

## Output events

Every line has `type`. Every line except a few carries `uuid` and `session_id`.

### `system` / `init`

First line of the session. Carries the fields Unified Dev needs to bind a session:

```json
{"type":"system","subtype":"init","session_id":"f93932c9-...","cwd":"/path",
 "model":"claude-sonnet-5","permissionMode":"bypassPermissions",
 "tools":["Bash","Read",...],"slash_commands":[...],"agents":[...],
 "output_style":"default","uuid":"..."}
```

`session_id` is what `--resume` takes later. Persist it the moment this arrives.

`--resume` looks for the transcript under `projects/` in the config directory the process starts
with, and nowhere else. Measured on `claude 2.1.309` on 29 October 2026, in a throwaway config
directory with no sign-in: with the transcript copied under `projects/` the session loads and the
turn runs, and with it missing the CLI prints `No conversation found with session ID: <id>` and
ends with `is_error: true`, `subtype: error_during_execution` and zero cost. The lookup happens
before authentication is checked, so a session started under one account cannot be resumed under
another, whichever of the two is signed in. `AgentSessionSettlement` is the decision: a stored id is
never cleared by a change of account. When the account recorded on the session is known and differs
from the one about to run, or when the owner deliberately moves a chat with no recorded account,
`Store.switchSegment` parks the id on the segment it belongs to and the chat continues on another
segment, which gets the id back if the chat returns to that account. A session with no recorded
account is otherwise left as it is, because nothing says where its transcript lives.

A `--resume` that finds no transcript ends the process at once: measured on `claude 2.1.309` on
29 October 2026, for an id that does not exist anywhere and for one that exists under another
config directory, no `system/init` arrives. The output is the plain line `No conversation found with session ID: <id>`,
then one `result` with `subtype: error_during_execution` whose `session_id` is the id that was asked
for, and exit status 1. `SegmentResume.refused` reads that shape, and only before the first `init` of
a process the owner has not stopped. The runner clears the stored id and sets the segment's cursor
to -1: the turn that was refused stays failed, and the next send opens a new session carrying the
whole conversation. An `init` naming another id than the one asked for
(`SegmentResume.lostHistory`) resets the cursor the same way, and nothing that turn replies moves it
again, because the prompt already sent carried no delta. Only the first `init` of a process is read
like this; a brand new session getting its first id is not a loss.

The same design is applied to Codex and Grok, whose threads also live under the directory the
account gives them (`CODEX_HOME`, `GROK_HOME`). Only Claude Code was measured. Nothing here says
what `thread/resume` does in another Codex home or what Grok's resume does in another Grok home.
Both runners treat any failed resume alike: they open a new thread or session, and only once that
has worked do they reset the cursor and replace the stored id. A server that is down therefore
changes nothing, and a resume that was really refused has the whole conversation in that same send.

`model` is the string `--model` was given, echoed rather than resolved or checked. A `--model`
nobody has ever heard of comes back in this field unchanged, so this line says what was asked for
and never what will answer.

### Which models it has, and what happens when it does not have one

There is nothing to ask, and a file to read instead. Measured on `claude 2.1.278` on 24 September
2026, none of it spending a turn.

No subcommand lists models: `agents`, `attach`, `auth`, `auto-mode`, `doctor`, `gateway`, `import`,
`install`, `logs`, `mcp`, `plugin`, `project`, `respawn`, `rm`, `setup-token`, `stop`,
`ultrareview`, `update`, and nothing else. Under `--input-format stream-json` the `init` line does
not arrive until the first user message is written to stdin either: a session started and left
alone printed seven `hook_started` and seven `hook_response` lines and then waited, with no `init`
and no `model` anywhere. So asking the process costs a turn and answers nothing useful.

**`~/.claude.json` carries the answer.** The CLI rewrites it on startup with what the server told
it, and `additionalModelOptionsCache` is the list its own `/model` picker is built from. It is the
same file `AgentCatalog.claudeAccountPath` already reads for the account, so this costs one more
read of a file the app opens anyway. As measured:

```json
"additionalModelOptionsCache": [
  {"value": "claude-fable-5-1[1m]", "label": "Fable",
   "description": "Fable 5.1 · Most capable for your hardest and longest-running tasks"},
  {"value": "cc-update-required-1", "label": "Opus 5.5 (disabled)",
   "description": "Update to 2.1.280+ to use Opus 5.5", "disabled": true}
]
```

Three things that shape `ClaudeModelOptions`. The list is **additional** options, so the four
aliases every install takes are not in it and stay in `ClaudeModelCatalog.builtIn`. A `value` is
not always a model id: `cc-update-required-1` is a placeholder for one this install cannot reach,
which is why the name comes from `label` when `ClaudeModelRank` does not recognise the id, and from
`ModelLabel` when it does, because `label` reads "Fable" for a model we would rather call
"Fable 5.1 (1m)". And `disabled` comes with its reason in `description`, which is worth showing
rather than hiding: on this machine it is the whole answer to why Opus 5.5 cannot be chosen.

`modelAccessCache` and `orgModelDefaultCache` sit beside it and were empty on the account measured,
so nothing is read from them yet.

`ClaudeModelSource` puts that read behind the same `AgentModelCache` Codex and Grok use, and joins
`AgentModelSource.live`, so a model that arrives after this build ships shows up on its own.

Nothing is checked at startup. A model that does not exist is refused only once a turn is sent, and
the refusal arrives in four places at once:

```
stderr:  [claude-code:unrecognized_model] {"model":"definitely-not-a-model","query_source":"sdk"}
exit:    1
result:  "is_error":true, "subtype":"success", "terminal_reason":"api_error", "total_cost_usd":0,
         "result":"There's an issue with the selected model (definitely-not-a-model). It may not
                   exist or you may not have access to it. Run --model to pick a different model."
```

`terminal_reason: api_error` is a bucket shared by every failure that happens at the API: a refused
model and a signed-out account both arrive under it, so it is only the anchor and the words decide.
A signed-out account was measured on `claude 2.1.309` on 29 October 2026 as `subtype: success`,
`is_error: true`, `num_turns: 1`, `terminal_reason: api_error` and `result: "Not logged in · Please
run /login"`, after an assistant message from model `<synthetic>` carrying `error:
authentication_failed`. `AgentAccountSignOut.measuredWords` and `measuredTerminalReason` are those
two fields.

The `subtype` stays `success`, so `is_error` is the only field in the `result` that marks it. The
name of the refused model is in the stderr line as JSON and in the `result` sentence as English, so
`ModelRefusal` reads the first and never the second. Note the shape of the failure: a `result`
**does** arrive, which is why `UnfinishedRun.of` has to let this one case past its `sawResult`
guard, or the exit that carries the marker is discarded and the turn fails saying nothing useful.

### `assistant`

**The important one.** Emitted once per content block, already split, with the block complete.
A transcript can be built from these alone: the `stream_event` deltas below are only needed to
show text arriving live.

```json
{"type":"assistant","uuid":"...","parent_tool_use_id":null,"session_id":"...",
 "message":{"id":"msg_011...","role":"assistant","model":"claude-sonnet-5",
   "stop_reason":null,
   "usage":{"input_tokens":2,"cache_creation_input_tokens":13435,
            "cache_read_input_tokens":24424,"output_tokens":2,
            "cache_creation":{"ephemeral_5m_input_tokens":0,"ephemeral_1h_input_tokens":13435},
            "service_tier":"standard"},
   "content":[ <exactly one block> ]}}
```

`content[0]` is one of:

| block | fields |
|---|---|
| `text` | `text` |
| `thinking` | `thinking`, `signature` |
| `tool_use` | `id` (`toolu_...`), `name`, `input` (arbitrary JSON object) |

`parent_tool_use_id` is non-null when the event comes from inside a subagent (the Agent tool).
Nest or indent those rows rather than mixing them into the main flow.

Several consecutive `assistant` events can share one `message.id`. That is one assistant turn
split across blocks, not several turns.

### `user`

A tool result being fed back. Not something a human typed.

```json
{"type":"user","uuid":"...","parent_tool_use_id":null,"session_id":"...",
 "message":{"role":"user","content":[
   {"type":"tool_result","tool_use_id":"toolu_01PpK...","content":"1\thello\n2\t",
    "is_error":null}]},
 "toolUseResult":null}
```

`content` is either a string or an array of blocks (`{"type":"text","text":...}`, and image
blocks for screenshots). `is_error` is `true` when the tool failed. Match `tool_use_id` back to
the `tool_use` block to render the pair as one row.

A call that never ran carries `tool_result_meta` on the same line, naming why:

```json
"tool_result_meta":[{"id":"toolu_01Xe8...","non_execution_kind":"permission-rule",
  "permission_decision":{"decision":"reject","source":"hook","reason_type":"hook"}}]
```

`non_execution_kind` is `permission-rule` for a `PreToolUse` hook too, so it cannot tell a hook from
a permission rule. `permission_decision` can: `decision` of `reject` with `source` of `hook` means
no permission mode would have let the call through, and `ToolRefusal.hookRefused` is that case. A
hook can also accept a call that is then interrupted, which is not a refusal of its. Measured on `claude 2.1.309`. The
message text is the hook's own and decides nothing. `permission_denials` on the `result` line lists
both, with only `tool_name`, `tool_use_id` and `tool_input`, so a turn's real denials are the ones
whose `tool_use_id` no hook refused.

### `stream_event`

Raw passthrough of the Anthropic streaming API, only present with `--include-partial-messages`.
Use for live typing, then reconcile against the `assistant` event that follows.

```json
{"type":"stream_event","event":{...},"session_id":"...","uuid":"...","parent_tool_use_id":null}
```

`event.type` is one of `message_start`, `content_block_start`, `content_block_delta`,
`content_block_stop`, `message_delta`, `message_stop`.

`content_block_start` carries `index` and `content_block` (`{"type":"text"|"thinking"|"tool_use",...}`).
`content_block_delta` carries `index` and `delta`, whose `type` is:

- `text_delta` with `text`
- `thinking_delta` with `thinking`
- `input_json_delta` with `partial_json` (accumulate the string, it parses only once complete)
- `signature_delta` with `signature`

### `system` (other subtypes)

- `status` with `status: "requesting"` and similar. Drives a "thinking" indicator.
- `thinking_tokens` with `estimated_tokens` and `estimated_tokens_delta`. Live thinking counter.
- `hook_started` / `hook_response` with `hook_name`, `hook_event`, `output`, `stdout`, `stderr`,
  `exit_code`, `outcome`. Payloads can be hundreds of kilobytes. Never render them raw.
- Unknown subtypes will appear over time. Ignore them without failing.

### `result`

Last line of a turn.

```json
{"type":"result","subtype":"success","is_error":false,
 "duration_ms":7880,"duration_api_ms":7851,"num_turns":3,
 "stop_reason":"end_turn","session_id":"...","total_cost_usd":0.119,
 "result":"Created out.txt with \"BATON\".",
 "usage":{"input_tokens":6,"output_tokens":360,
          "cache_read_input_tokens":100420,"cache_creation_input_tokens":13928,
          "output_tokens_details":{"thinking_tokens":150}},
 "modelUsage":{"claude-sonnet-5":{"contextWindow":1000000,"costUSD":0.119,...}},
 "permission_denials":[],"terminal_reason":"completed","uuid":"..."}
```

`subtype` is `success`, or `error_max_turns` / `error_during_execution` on failure.
`modelUsage.<model>.contextWindow` is where the context-window size comes from, so a
"how full is the context" gauge can be drawn.

**It is the last line of a turn, and not always of the turn you sent.** The CLI starts turns of
its own, and when it does the result carries an `origin` object naming why:

```json
{"type":"result","subtype":"success","is_error":false,"duration_ms":60,
 "duration_api_ms":0,"num_turns":0,"result":"","origin":{"kind":"task-notification"},...}
```

Measured on 25 August 2026, twice, in two workspaces. Both times a `--resume` brought back a
session that had a background task notification waiting for it, and the CLI ran that as a turn
before it read anything from stdin: `init`, this line, then a second `init` for the turn the user
had actually sent. A result answering a prompt names no origin at all. See `StrayResult`, which is
the bug that cost.

The same thing happens mid process, and there the turn does real work. Measured on `claude
2.1.268` on 11 September 2026: a turn put `sleep 5` in the background and ended; five seconds later
the CLI wrote `task_updated`, then `system/task_notification` for the command, then a second `init`,
then a whole turn, closed by a `result` with `origin: task-notification`. The notification is the
only line saying why that turn began, and its `summary` reads `Background command "<description>"
completed (exit code 0)`. Unified Dev stores it when it arrives between turns and draws it as the turn's
opening line. See `BackgroundWake`.

### A turn stopped by the usage limit

Measured in Claude Code's own transcript files (`~/.claude/projects`, versions 2.1.219 to 2.1.237),
the stop is an `assistant` line, not a `result` and not a `system` line. It has model `<synthetic>`, zero
usage, one `text` block and three top-level fields beside `message`:

```json
{"type":"assistant","message":{"model":"<synthetic>","role":"assistant","stop_reason":"stop_sequence",
 "content":[{"type":"text","text":"You've hit your session limit · resets 7:10am (Europe/Luxembourg)"}]},
 "error":"rate_limit","isApiErrorMessage":true,"apiErrorStatus":429}
```

Later versions add `quotaLimits` (`status: rejected`, `rateLimitType: five_hour`, `resetsAt`,
`overageStatus`, `upgradePaths`). The words name the window that ran out (`session` in every sample);
the `resets` clause is local time and carries no date.

`AgentEvent.decode` turns that line into `.assistantText`, so it is stored as an `assistantText` row
with the whole line as its payload. The `result` line that the CLI writes after a synthetic API error
(see the signed-out account above) was not captured for a limit: transcript files do not hold
`result` lines. If one arrives it is a `result` row, and `ConversationHandoff` counts that turn as
complete. `TurnStopCause` therefore reads the `assistantText` row, which needs `error: rate_limit`,
status 429, model `<synthetic>` and text starting `You've hit your` and containing `limit`; the
other `rate_limit` 429s are not treated as the limit. Only the last turn counts (rows after the last
`user` row), and the limit row must be the last output in it.

### `rate_limit_event`

One per turn, and it carries **one window**, never a set:

```json
{"type":"rate_limit_event","rate_limit_info":{"status":"allowed","resetsAt":1787508600,
 "rateLimitType":"five_hour","overageStatus":"rejected",
 "overageDisabledReason":"org_level_disabled","isUsingOverage":false},"uuid":"...","session_id":"..."}
```

Measured on 23 August 2026 against the installed binary, and recorded with a second payload from a
busier account in `Tests/fixtures/rate-limits.jsonl`. Three facts, all of which shaped `AgentQuota`:

1. `rateLimitType` names a single window. `five_hour` and `seven_day` are the values observed, there
   is no array, and there is no way to ask for the rest, so what Unified Dev knows about an account
   accumulates over turns.
2. **`utilization` is absent below a warning threshold.** The payload above has no usage figure at
   all. The one that does carries `"status":"allowed_warning"` and `"surpassedThreshold":0.75`
   beside it, so the number arrives only once the account is near the wall. Store that as unknown,
   never as zero: an empty bar is a claim, and it is a claim this protocol never made.
3. **There is no monthly window.** Unified Dev shows the two it is given and says nothing about a third.

Surface it quietly, never as an error. `AgentQuotaAdapters` is the reader.

### `control_request` / `control_response`

Not an event, a question. With `--permission-prompt-tool stdio` the CLI asks before running a tool
it is not allowed to run outright, and holds the turn open until an answer arrives on stdin.

```json
{"type":"control_request","request_id":"…",
 "request":{"subtype":"can_use_tool","tool_name":"Bash","input":{…},
            "permission_suggestions":[…]}}
```

Only `can_use_tool` is lifted out. The other control subtypes are the CLI answering Unified Dev, or
asking something Unified Dev has no business answering, and they stay raw rather than half understood.
`request` also carries `display_name`, `tool_use_id`, `description`, `decision_reason`,
`decision_reason_type`, `blocked_path`, `suppress_always_allow_rule`, `requires_user_interaction`
and `classifier_approvable`, all optional. **`decision_reason` may carry ANSI escapes**, which the
CLI's own schema says in as many words, so it is stripped before anything renders it.

The answer is one line back:

```json
{"type":"control_response","response":{"request_id":"…","subtype":"success",
 "response":{"behavior":"allow"|"deny",…}}}
```

An allow carries `updatedInput`, which is the input that was asked about and unedited unless the
tool asked a question the user typed an answer to. A wider scope than once carries
`updatedPermissions`, which is the CLI's own suggestion aimed at the session. A deny carries
`message` and `interrupt`. The `request_id` has to match the pending ask or the answer does
nothing: the CLI refuses a response whose tool disagrees with the question and logs the mismatch.
`PermissionAsk` reads these and `PermissionAnswer` writes them.

This wire used to fall through to `unknown` and be dropped on the floor, which is exactly what
"Unified Dev never asks" looked like from the inside: the CLI was willing to ask and nobody was reading
the line. A decoder that took the event list above as complete would hang the turn the same way.

## Rules for the decoder

1. **Never fail the stream on an unknown event.** New `type` and `subtype` values ship
   regularly. Decode what is recognised, keep the raw JSON for everything else, carry on.
2. **Keep the raw line.** Unified Dev stores the original JSON for every row so a renderer added later
   can show detail that was not decoded at the time.
3. Lines can be very large (a hook response, a big tool result). No length assumptions.
4. A malformed line is possible if the CLI crashes mid-write. Skip it, do not abort.
