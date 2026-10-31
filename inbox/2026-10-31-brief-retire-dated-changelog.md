# Brief: retire onekeys' dated changelog

2026-10-31. From a claude-plugin-dev session surveying the changelog convention
across the ddaanet repos. A proposal, not a decision. Nothing in this repo was
edited.

## Proposal

Retire dated write-time records (`docs/changelog/YYYY-MM-DD-slug.md`) and the
`docs/changelog.md` index in favour of git history; keep `docs/design.md` as the
living design. The reasons: a record restates its commit (both records here
landed with their change); the shared rule says a summary of a change points at
the diff rather than narrating it; git keeps the archaeology; and the size check
being designed in claude-plugin-dev loses an exemption. The source of the
convention is craft's `design-doc-writing`; its brief is
`craft/inbox/2026-10-31-brief-retire-dated-changelog.md`.

## Touch points

- `docs/changelog.md` (12 lines) and its two records,
  `docs/changelog/2026-05-31-reconcile-mapping.md` and
  `docs/changelog/2026-07-25-unambiguous-expansions.md`: deleted; git keeps
  them.
- The index lines carry the release version (v0.3.0, v0.3.2); the release tags
  already carry it.
- `CLAUDE.md:27–28`, the layout entry.
- No gate here reads the changelog; `plugin-dev/check-refs.sh` exempts
  `docs/changelog/` by default and changes only through a toolkit release.

Release notes are out of scope: nothing user-facing reads the changelog, and
`dist.include` does not ship `docs/`.
