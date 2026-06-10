# onekeys

A Claude Code plugin that expands single-character prompts into full
instructions. Type one key and onekeys turns it into the message you
meant.

## How it works

A `UserPromptSubmit` hook inspects every prompt. When your **entire
prompt is a single character** that matches a key in your mapping, the
hook injects context telling Claude to act on the expansion. Longer
prompts pass through untouched.

A hook cannot rewrite your prompt or run a slash command directly, so
onekeys injects the expansion as authoritative intent. For slash-command
expansions (e.g. `h → /handoff:handoff`) Claude invokes the matching
command/skill itself.

## Mapping

Mappings live in `~/.claude/onekeyers.txt`, auto-created with these
defaults on first use:

```
c Continue
r Retry
h /handoff:handoff
H /handoff, /commit
n What's next?
s Status.
w What do you think?
y Yes
```

Format: `char<space>expansion`, one per line. The first space splits the
key from the expansion, so expansions may contain spaces. Keys are
single characters and case-sensitive (`h` and `H` differ). Blank lines
and `#` comments are ignored. Edit the file to add your own.

## Staying current with new defaults

The mapping is not frozen after the first run. When a new onekeys version
ships different defaults, your file is **reconciled** with them on the
next single-character prompt — a 3-way merge (via `diff3`) that pulls in
the new defaults while keeping your own edits.

To do this without guessing, onekeys keeps a second file,
`~/.claude/onekeyers.base.txt`, recording the defaults as of the last
reconcile. It is the common ancestor of the merge; leave it alone.

- **No clash** → the merge is applied silently. You just get the new
  defaults, your customizations intact.
- **A clash** (you edited a key the new defaults also changed) → onekeys
  does **not** touch your live file. It writes the merge — with the
  ancestor shown between `<<<<<<<`/`|||||||`/`>>>>>>>` markers so the
  three versions are legible — to `~/.claude/onekeyers.txt.merge` and
  nudges you once. Resolve that file, delete the markers, and the next
  onekey press promotes it into place.

Requires `diff3` (from GNU diffutils, normally already present). Without
it, onekeys falls back to seed-on-first-run and never reconciles.

## License

MIT
