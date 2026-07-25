# onekeys — Design

Living design document: why the project has the shape it has. The full
original specification is at
`docs/superpowers/specs/2026-05-27-onekeys-design.md`.

## Mechanism

A `UserPromptSubmit` hook cannot rewrite the prompt text or cause the CLI
to execute a slash command. On exit 0 it can only inject
`additionalContext`. onekeys therefore injects the expansion as
authoritative user intent rather than rewriting the prompt: Claude reads
the context and acts on it, invoking the matching command/skill itself
for slash-command expansions. The literal one-character prompt is
meaningless on its own, so the injected expansion dominates.

## Trigger: exactly one character

Only a prompt whose trimmed text is exactly one character is a candidate.
This is the disambiguation guard — ordinary multi-character prompts are
never touched. Keys are case-sensitive so `h` (handoff) and `H` (handoff
+ commit) are distinct.

## Mapping: global, auto-seeded

The mapping is global (`~/.claude/onekeyers.txt`), not per-project: these
shortcuts are workflow habits the user wants in every repository. The
hook seeds the file with defaults when absent, making it
self-bootstrapping and hand-editable. No project-level override — the
extra precedence layer was judged unnecessary (YAGNI).

## Expansions are imperatives

An expansion arrives as `additionalContext` with no other user text to
anchor it, so the expansion alone determines the action. A default whose
text reads as a topic rather than an instruction leaves the choice to
inference, and keys with overlapping meanings collapse into whichever
reading is most available. So each default names its action outright, plus
any constraint that distinguishes it — `p` is "List pending tasks, no tool
use allowed.", not "What's next?".

## Keeping the mapping current: 3-way reconcile

Seeding only on first run froze the file: once it existed, shipped changes
to the defaults never reached an installed user. Reconcile fixes that
without discarding their edits, by treating the file as a 3-way merge each
time a onekey is pressed — MINE is the live file, OTHER is the shipped
defaults, and **BASE** is `~/.claude/onekeyers.base.txt`, the defaults as
of the last reconcile.

The base is the load-bearing piece. A merge that knows only MINE and OTHER
cannot tell a user's customization from a new default — every differing
line looks like a conflict, and a conflict with no ancestor cannot explain
*what* delta is being combined. Persisting BASE makes the common case
(defaults unchanged since last reconcile) a single `cmp` and the conflict
case legible. `diff3 -m` is used precisely because it emits the base
section (`|||||||`) in conflicts; the two-way merge styles that omit it
would defeat the point.

On conflict the live file is left strictly untouched — it is the file the
user types against, so injecting merge markers into it would be hostile.
The merge instead lands in a sidecar (`~/.claude/onekeyers.txt.merge`) with
a one-time `systemMessage` notice; once the user strips the markers, the
next reconcile promotes the resolved sidecar and advances the base. The
mainline (no conflict) stays fully transparent.

Reconcile runs *behind* the single-character gate, so the every-prompt
passthrough path is unchanged. `diff3` is a soft dependency: if it is
absent the hook degrades to seed-on-first-run rather than failing.

## Release infrastructure

The repo consumes `claude-plugin-dev` (vendored at `v0.2.0` via
`git subtree`): the `release` recipe and the version-guard hook. The
plugin manifest holds the last-released version; `just release` bumps it.
