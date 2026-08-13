# 2026-07-25 — Dropped ambiguous `n`/`s` defaults for an imperative `p` (v0.3.2)

`n` ("What's next?") and `s` ("Status.") were both acted on as "list pending
tasks" — `n` also as "continue" — because an expansion arrives as
`additionalContext` with no other user text to anchor it: the expansion
alone has to determine the action. A default that reads as a topic rather
than an instruction leaves the choice to inference, and keys with
overlapping meanings collapse into whichever reading is most available.

Replaced both with `p` → "List pending tasks, no tool use allowed." —
naming the action outright, plus the constraint that distinguishes it from
just doing the tasks. Existing installs pick up the new mapping on the next
onekey press via the 3-way reconcile; no migration needed.

See "Expansions are imperatives" in [design.md](../design.md).
