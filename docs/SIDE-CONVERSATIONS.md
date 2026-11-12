# Side conversations

Use `/btw` or the side-question button beside the composer to open a floating conversation.
`/btw Why this approach?` opens it and sends the question. Follow-ups go to its own agent while
work in the original chat continues. Escape hides the overlay, and `/btw` or Reply brings back the
same one. The close button ends it: its agent stops, its session is archived, and the next `/btw` or
Reply starts a fresh one with only the new quote, an empty transcript and context taken from the
main chat at that moment. Opening one always creates a new session and archives any earlier side
conversation of the same chat that was never kept, so a side conversation does not outlive the
window that held it.
The child inherits the parent's provider, model, reasoning, permissions and composer settings.

**Keep as chat** gives the same conversation a regular tab. It preserves the provider session,
draft, history and any running turn. **Keep and start new** keeps the current detour as a tab and
opens another with fresh context. Closing the parent also keeps its side conversation, so a
running answer or approval request cannot become unreachable.

## Context

Unified Dev starts a separate provider session with a snapshot of the parent's recent conversation.
It does not resume or steer the parent's provider session. The snapshot includes user and
assistant text, bounded tool arguments and results, and the answer streaming when it was opened.
The snapshot takes up to 300 stored events and keeps the latest 32,000 characters; individual
tool records are limited to 2,000 characters. It does not include private reasoning or later
activity in the parent.

The snapshot is attached to the first provider prompt as quoted background. The editable draft,
queue and visible user bubble retain the actual question. Failed first submissions keep the
context available for retry. Codex acknowledges it after accepting the turn; the other runner
acknowledges it when the first answer or thinking block arrives. Subsequent turns resume the
child's own conversation.

## Storage and lifetime

`Session.sideConversationParentID` marks a temporary conversation. It is separate from
`parentSessionID`, which means an agent-created crew member. `TabSet` hides the temporary session
from the normal strip. Promotion clears the temporary parent column and leaves the snapshot in
the session settings for provenance. A database trigger promotes children when their parent is
archived, including replacement through `/clear` or `/close`.

The workspace owns the overlay state and the ordinary `TranscriptModel` owns the child runner.
`SideConversationLifecycle` in Core decides what a start, a close and a keep do, including an
opening that is closed before it arrives, which is archived as soon as it lands, and a
"Keep and start new" whose keep fails, which restores the conversation it was keeping. Hiding the view
stops neither agent; closing stops the side conversation's. Workspace teardown cancels pending opening tasks and
stops all its runners. The floating composer excludes workspace review comments, and the native
Stop Agent command follows composer focus.
