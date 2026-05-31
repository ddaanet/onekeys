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
H /handoff, /commit, /autoname
t /autoname
n Next?
w What do you think?
y Yes
```

Format: `char<space>expansion`, one per line. The first space splits the
key from the expansion, so expansions may contain spaces. Keys are
single characters and case-sensitive (`h` and `H` differ). Blank lines
and `#` comments are ignored. Edit the file to add your own.

## License

MIT
