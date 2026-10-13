## Brief: upgrade the vendored plugin-dev toolkit to 0.6.1

2026-08-28

### What to do

```sh
just update-plugin-dev dist-v0.6.1
```

Requires a clean tree — the recipe refuses a dirty one. Commit or stash your own
work first. After it lands, `cat plugin-dev/VERSION` should read `0.6.1`.

### Decisions

- **Pin `dist-v0.6.1`, never `v0.6.1` and never `main`.** The `dist-` tag is a
  `git subtree split --prefix=toolkit`, so its root tree holds only the eight
  consumer-facing files. The bare source tag would drag in the toolkit repo's own
  working environment — its `memory` submodule, `.claude/`, `CLAUDE.md`, its own
  justfile. Both `install.sh` and `update-plugin-dev` refuse a source ref and name
  the `dist-` one instead; a branch or sha is refused outright.
- **Never hand-edit anything under `plugin-dev/`.** It is generated, read-only
  vendored content. Fixes go to the claude-plugin-dev repo, get a tagged release,
  and arrive here through this recipe.

### Constraints

- The commit gate must run. Never `--no-verify`.
- Do not create or switch branches for this. Work on whatever is checked out.

### Rejected approaches

- Tracking `main` — defeats reproducibility; an old tag of this plugin should
  still resolve to the exact toolkit content vendored at the time.
- Hand-deleting leaked `plugin-dev/` paths before the pull — unnecessary, see below.

### Additional context

**What 0.6.1 carries** — five `release.sh` fixes plus drift-proofed docs: the
manifest is rolled back when a commit gate refuses the release; a failed
writability probe keeps mktemp's own words; the recovery loop is named when the
release push is refused; the memory submodule path is read from `.gitmodules`
keyed on `gitlore-memory` instead of being hardcoded to `memory`; and `CDPATH` is
unset in the hook test harness. The README's install block now resolves the newest
`dist-` tag from the remote, so it no longer names a version that can go stale.

**If this repo is still pre-0.6.0** (check `cat plugin-dev/VERSION`) it also
carries the toolkit's leaked working environment under `plugin-dev/` — most
visibly a `plugin-dev/memory` gitlink that makes a bare `git submodule status`
fail for the whole repo. No manual cleanup is needed: the first pull of a `dist-`
tag deletes all of it in the same commit. Expect two recoverable snags:

1. The gitmoji commit-msg hook rejects the subtree squash message, leaving a
   correct staged merge. Finish it by hand with a conventional message. Do not
   run `git checkout` first — that would discard the staged merge.
2. A modify/delete conflict on a vendored file the dist ref no longer ships.
   Resolve by deleting it, after confirming the local edit exists upstream.

**A resting `memory` submodule blocks the pull.** A ` M memory` entry — the
state a gitlore commit-and-gate flow leaves behind — is enough on its own to fail
`git diff --quiet HEAD`. `release.sh` was taught to tolerate it, but
`update-plugin-dev` and `git subtree pull` were not, and subtree's own internal
check is not something the toolkit can relax with a pathspec. Clear it by letting
the parent repo's pre-commit hook commit memory (make any commit), then pull.

**Verifying afterwards** — `git ls-tree -r HEAD plugin-dev/ | grep 160000` should
print nothing, and `git ls-files 'plugin-dev/*'` should list exactly: `LICENSE`,
`README.md`, `VERSION`, `check-version.sh`, `install.sh`, `release.just`,
`release.sh`, `version-guard.sh`. Then `just check-version` to confirm the
manifest and marketplace agree.
