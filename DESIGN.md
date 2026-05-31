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
+ commit + autoname) are distinct.

## Mapping: global, auto-seeded

The mapping is global (`~/.claude/onekeyers.txt`), not per-project: these
shortcuts are workflow habits the user wants in every repository. The
hook seeds the file with defaults when absent, making it
self-bootstrapping and hand-editable. No project-level override — the
extra precedence layer was judged unnecessary (YAGNI).

## Release infrastructure

The repo consumes `claude-plugin-dev` (vendored at `v0.2.0` via
`git subtree`): the `release` recipe and the version-guard hook. The
plugin manifest holds the last-released version; `just release` bumps it.
