# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# onekeys

A Claude Code plugin: a `UserPromptSubmit` hook that expands
single-character prompts into full instructions. See `DESIGN.md` for the
rationale and `docs/superpowers/specs/2026-05-27-onekeys-design.md` for
the full spec.

## Layout

- `scripts/onekeys-hook.sh` — the hook. Reads `.prompt` from stdin JSON;
  if the trimmed prompt is exactly one character present in
  `~/.claude/onekeyers.txt`, emits `additionalContext` with the
  expansion; otherwise no output. Seeds the mapping with defaults when
  absent.
- `hooks/hooks.json` — registers the hook on `UserPromptSubmit`.
- `tests/hook-test.sh` — runs the hook under a temporary `HOME`.
- `plugin-dev/` — vendored `claude-plugin-dev` toolkit (release recipe +
  version-guard hook). Do not edit by hand; update with
  `just update-plugin-dev vX.Y.Z`.

## Quality gate

```sh
just precommit
```

Validates the manifest and hooks JSON, parses and shellchecks the
scripts, and runs the hook tests. Must be green before committing.

## Conventions

- **The hook fires on every prompt** (`UserPromptSubmit` takes no
  matcher), so the no-match path must stay cheap and silent.
- **A `UserPromptSubmit` hook cannot rewrite the prompt or run a slash
  command.** It only injects context. Don't design features that assume
  otherwise.
- **The mapping is global** (`~/.claude/onekeyers.txt`). Tests must run
  under a temporary `HOME` so they never touch the real file.
- **`${CLAUDE_PLUGIN_ROOT}` in `hooks/hooks.json` is expanded by Claude
  Code at hook-fire time**, not by the shell. Keep it literal.
- **`plugin.json`'s `.version` is the last released version**; the
  `release` recipe bumps it and the version-guard hook blocks manual
  edits.

## Releasing

```sh
just release [patch|minor|major]
```

Provided by the vendored `plugin-dev/release.just`. See
`plugin-dev/README.md`.
