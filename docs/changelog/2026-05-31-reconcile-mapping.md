# 2026-05-31 — Mapping reconciled with shipped defaults via 3-way merge (v0.3.0)

Seeding `~/.claude/onekeyers.txt` only on first run froze the mapping: once
the file existed, later changes to the shipped defaults never reached an
installed user. Reconcile fixes that without discarding a user's own edits,
by treating the mapping as a 3-way merge on every single-character prompt —
MINE the live file, OTHER the shipped defaults, BASE
`~/.claude/onekeyers.base.txt` (the defaults as of the last reconcile).

`diff3 -m` was chosen specifically because it surfaces the base section
(`|||||||`) in conflicts; two-way merge styles that omit it would defeat the
point of keeping BASE at all. On conflict the live file is left untouched —
it's what the user types against — and the merge lands in a sidecar
(`~/.claude/onekeyers.txt.merge`) with a one-time `systemMessage` notice.
`diff3` is a soft dependency: its absence degrades to seed-on-first-run
rather than breaking the prompt.

See "Keeping the mapping current: 3-way reconcile" in
[design.md](../design.md).
