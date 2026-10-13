## Brief: https submodule urls for keyless /plugin install (onekeys)

2026-10-13

### Goal

Installing the `onekeys` plugin through `/plugin` must never need a GitHub SSH key. Claude Code's `/plugin install` clones with `--recurse-submodules`. The gitlore `memory` submodule url, and the nested tier url inside it, are in SSH form, so a user with no registered key gets `Permission denied (publickey)` and the whole install aborts.

### Decisions

- Change only `.gitmodules` url values to `https://github.com/...`. Local `.git/config` urls stay SSH, so my human partner's pushes are unaffected.
- Worked example: the `sandbox-lies` repo, `dev` branch, commit "https submodule urls, so a marketplace install needs no access to the memory repos". A keyless real install of it succeeded once both urls were https (Claude Code 2.1.296).

### Edits for this repo

- `.gitmodules` (repo root): `url = git@github.com:ddaanet/onekeys-gitlore-memory.git` becomes `url = https://github.com/ddaanet/onekeys-gitlore-memory.git`.
- `memory/.gitmodules`: `url = git@github.com:ddaanet/ddaanet-memory.git` becomes `url = https://github.com/ddaanet/ddaanet-memory.git`.
- This second edit lives inside the memory submodule, so it lands through the gitlore commit path (a commit in the memory repo), and the memory must be published afterwards (`/gitlore:push`) so the parent's recorded memory commit exists on the remote.

### Target visibility (checked 2026-10-13, anonymous GitHub API)

- `ddaanet/onekeys-gitlore-memory`: 404, private or missing. An anonymous install fails until my human partner makes it public. The agent must NOT change visibility itself; ask my human partner to do it.
- `ddaanet/ddaanet-memory`: 200, public.

### Constraints

- Only `.gitmodules` files change. Do not touch `.git/config`.
- Use the Read tool for `.gitmodules`, not `cat` in Bash: the command sandbox masks it.

### Verification

After the changes are pushed and the memory repos are public:

`HOME="$TMPDIR/anon" GIT_CONFIG_NOSYSTEM=1 GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND=false git -c credential.helper= clone --recurse-submodules https://github.com/ddaanet/onekeys.git "$TMPDIR/anon-clone"`

Expected exit 0 with `memory/ddaanet/` populated. A credential-less clone fails on any SSH submodule url, and fails on any private repo in the chain.
