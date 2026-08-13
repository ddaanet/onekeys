# onekeys — Design

## Summary

`onekeys` is a Claude Code plugin with a single `UserPromptSubmit` hook.
When the user's **entire prompt is one character** that matches a
configured key, the hook injects context instructing Claude to treat the
message as the mapped expansion. Prompts longer than one character pass
through untouched.

The plugin is a [`claude-plugin-dev`](https://github.com/ddaanet/claude-plugin-dev)
consumer: the release toolkit is vendored at tag `v0.2.0` via
`git subtree`, providing the `release` recipe and the version-guard hook.

## Motivation

Frequent, repetitive replies during a Claude Code session ("Continue",
"Retry", "Yes", "What do you think?", or kicking off `/handoff`) cost
keystrokes and break flow. `onekeys` lets the user type a single
character and have it expand to the full intent — fewer keystrokes, and
the terse character is disambiguated into an unambiguous instruction
before Claude acts on it.

## Mechanism

A `UserPromptSubmit` hook **cannot** rewrite the prompt text or cause the
CLI to execute a slash command; on exit 0 it can only inject
`additionalContext` that Claude reads alongside the original prompt
(confirmed against current hook docs and the `handoff` plugin's
`prompt-pre-hook.sh`).

`onekeys` works within that constraint by injecting the expansion as
**authoritative user intent**. For a matched key the hook emits:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "The user's prompt is the onekeys shorthand `h`, which expands to: /handoff:handoff. Act on the expansion as if the user had typed it; if it is a slash command, run that command."
  }
}
```

The single phrasing covers both cases:

- **Plain instruction** (`c → Continue`): Claude acts on the instruction.
- **Slash command** (`h → /handoff:handoff`): Claude invokes the matching
  command/skill via its normal tools (e.g. the `Skill` tool for
  `handoff`). The hook does not — and cannot — execute it directly.

The original one-character prompt is still present, but it is meaningless
on its own, so the injected expansion dominates.

## Trigger logic

The hook (`scripts/onekeys-hook.sh`, bash + jq, matching the `handoff`
script convention):

1. Read stdin JSON; extract `.prompt`.
2. Trim leading/trailing whitespace.
3. If the trimmed prompt is **exactly one character** *and* that
   character is a key in the mapping → emit the `additionalContext` JSON
   and exit 0.
4. Otherwise emit nothing and exit 0 — the prompt passes through
   unchanged.

The hook fires on every prompt (`UserPromptSubmit` takes no matcher), so
the no-match path must stay cheap: a couple of `jq` reads, a length
check, a lookup. No output on the common path.

Keys are **case-sensitive**, so `h` and `H` are distinct entries.

## Mapping file

- **Scope: global only.** Path: `~/.claude/onekeyers.txt`. There is no
  project-level override.
- **Auto-seeded.** On run, if the file is absent the hook creates it with
  the seven defaults below (embedded in the script as a heredoc), then
  reads it. Self-bootstrapping and hand-editable.
- **Format:** `char<space>expansion`, one entry per line. The *first*
  space splits the key from the expansion, so expansions may themselves
  contain spaces (e.g. `What do you think?`, `/handoff and /commit`).
  Blank lines and lines beginning with `#` are ignored. Entries whose key
  is not a single character are dead (the lookup only matches
  single-character prompts) and are harmlessly skipped.

Default seed:

```
c Continue
r Retry
h /handoff:handoff
H /handoff and /commit
n No
w What do you think?
y Yes
```

## Repository layout

A `claude-plugin-dev` consumer plugin:

```
.claude-plugin/plugin.json   # name "onekeys", version "0.1.0", description, author, MIT
hooks/hooks.json             # UserPromptSubmit -> bash ${CLAUDE_PLUGIN_ROOT}/scripts/onekeys-hook.sh
scripts/onekeys-hook.sh      # the hook; default seed embedded as a heredoc
plugin-dev/                  # vendored claude-plugin-dev via git subtree at v0.2.0
justfile                     # `import 'plugin-dev/release.just'` + a `precommit` recipe
.claude/settings.json        # version-guard PreToolUse hook (wired by plugin-dev/install.sh)
tests/hook-test.sh           # pipes sample JSON to the hook, asserts on stdout
README.md
DESIGN.md
CLAUDE.md
.gitignore
```

Bootstrapping the toolkit follows the `claude-plugin-dev` README: clone
at `v0.2.0`, run its `install.sh v0.2.0` from the plugin root (vendors the
subtree, adds the justfile import, wires the version-guard hook).

## Testing

`tests/hook-test.sh` runs the hook under a **temporary `HOME`** so it
never touches the real `~/.claude`. It pipes crafted `UserPromptSubmit`
JSON to the script and asserts on stdout:

- `c` → `additionalContext` contains `Continue`.
- `h` → contains `/handoff:handoff`.
- `H` → contains `/handoff and /commit` (verifies case sensitivity vs `h`).
- unmapped single char `x` → no output (passthrough).
- multi-character prompt `hello` → no output.
- whitespace-padded `" c "` → triggers (trimming).
- file absent under the temp `HOME` → gets seeded with the seven defaults.

`precommit` recipe (depended on by `release`):

```just
import 'plugin-dev/release.just'

precommit:
    jq . .claude-plugin/plugin.json > /dev/null
    bash -n scripts/*.sh
    shellcheck scripts/*.sh
    bash tests/hook-test.sh
```

## Non-goals (YAGNI)

- No project-level mapping override — global file only.
- No `/onekeys` management command — the mapping is edited by hand.
- No multi-character shortcuts — only single-character prompts trigger.
- No prompt *rewriting* — not possible for a `UserPromptSubmit` hook; the
  injected context is the mechanism.
