# onekeys Changelog

How the design got to its current shape. Each entry is a write-time record of
one change: what moved, and the reasoning available at the time. Entries are
never revised — a dated record is correct forever precisely because it is
dated. The living design is [design.md](design.md); when a decision there is
overturned, it is rewritten in place and the reversal gets an entry here.

Newest first.

- [2026-07-25 — Dropped ambiguous `n`/`s` defaults for an imperative `p`](changelog/2026-07-25-unambiguous-expansions.md) — vague expansions were conflated with neighbouring keys (v0.3.2)
- [2026-05-31 — Mapping reconciled with shipped defaults via 3-way merge](changelog/2026-05-31-reconcile-mapping.md) — seed-once had frozen the mapping against later default changes (v0.3.0)
