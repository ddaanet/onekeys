# onekeys Reconcile Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. This repo was built with tests-after rather than strict TDD, so each new/changed test assertion MUST be mutation-validated (turned red by a deliberate fault) per the project's `test-validation-by-mutation` memory.

**Goal:** Make the global mapping `~/.claude/onekeyers.txt` *reconcile* with shipped defaults on update, instead of being frozen after first seed. Today the hook only calls `seed_if_absent`, so once the file exists it never sees new defaults — every mapping change we ship reaches existing users only by hand-editing their file. Reconcile fixes that while preserving user customizations.

**Approach (decided):** A 3-way merge using `diff3 -m MINE BASE OTHER`, with a persisted **base** so conflicts can show the common ancestor (a conflict with only MINE/OTHER can't reveal the delta being combined). Conflict policy is **(b)**: never inject conflict markers into the live file the user types against — write the 3-way result (base markers included) to a sidecar and nudge via `systemMessage`.

**The three merge inputs:**
- **OTHER** — newly shipped defaults (the heredoc in the script), materialized to a temp file.
- **MINE** — the user's live `~/.claude/onekeyers.txt`.
- **BASE** — `~/.claude/onekeyers.base.txt`: the defaults as of the last reconcile. *New persisted artifact; the missing piece today.*
- **Sidecar** — `~/.claude/onekeyers.txt.merge`: the conflict surface (option b).

**Tech Stack:** bash, `jq`, `diff3` (GNU diffutils — new dependency), Claude Code plugin hooks. All three side files live under `~/.claude/` (user home), so no repo `.gitignore` changes are needed.

**Note on commits:** the gitmoji commit-msg hook rewrites `feat:`/`docs:`/`test:` prefixes to emoji on commit. Use the conventional prefixes below; the hook handles the rest.

---

## Reconcile algorithm

Runs **behind the single-character gate**, replacing `seed_if_absent`. Multi-character prompts still hit the early `exit 0`, so the hot passthrough path is unchanged. When `OTHER == BASE` (the common case — defaults unmoved since last reconcile) it is a single `cmp -s` and out; `diff3` only runs the turn after we ship a change.

```
reconcile():
  materialize OTHER (print_defaults > $tmp/other)

  # diff3 must exist; if not, fall back to legacy seed-or-skip and return.
  command -v diff3 || { [ -e MINE ] || { cp OTHER MINE; cp OTHER BASE; }; return; }

  # 1. First ever run: seed both MINE and BASE.
  if MINE absent:
      cp OTHER MINE; cp OTHER BASE; return

  # 2. A resolution is in flight (sidecar present).
  if SIDECAR present:
      if SIDECAR has NO conflict markers:        # user finished resolving
          mv SIDECAR MINE; cp OTHER BASE         # promote, advance base
      # else: still has markers -> stay silent, untouched
      return

  # 3. Migration: live file predates base tracking. Adopt user's file as authoritative.
  if BASE absent:
      cp OTHER BASE; return                      # no merge

  # 4. Defaults unchanged since last reconcile -> nothing to do (cheap path).
  if cmp -s BASE OTHER: return

  # 5. Defaults changed -> 3-way merge.
  set +e; merged=$(diff3 -m MINE BASE OTHER); rc=$?; set -e
  case rc in
    0)  printf '%s' "$merged" > MINE; cp OTHER BASE        # clean -> transparent
        rm -f SIDECAR ;;                                   # clear any stale sidecar
    1)  printf '%s' "$merged" > SIDECAR; NAG=1             # conflict -> sidecar (b)
        ;;                                                 # MINE untouched, BASE NOT advanced
    *)  : ;;                                               # diff3 trouble -> fail safe, do nothing
  esac
```

**Properties:**
- **Transparent mainline:** no customization, or non-overlapping customization → clean merge applied silently, base advances.
- **Useful manual case:** overlapping change → `diff3 -m` sidecar carries the `||||||| base` section, so the user can see *their* line, the *old default*, and the *new default* together. They resolve in the sidecar; on the next onekey press a marker-free sidecar is promoted to the live file and base advances.
- **Never corrupts the working file:** MINE only changes on a clean merge or an explicit, completed resolution.
- **No re-nag storm:** the `systemMessage` fires once (when the sidecar is first written); subsequent prompts short-circuit at step 2 and stay silent.
- **Fail safe:** missing `diff3` or `diff3` trouble (rc ≥ 2) degrades to leaving the user's file exactly as-is.

**`set -e` care:** `diff3` exits 1 on conflict, which would abort under `set -euo pipefail`. Capture `rc` inside a `set +e`/`set -e` fence as shown.

---

### Task 1: Refactor defaults into a reusable emitter

**Files:** Modify `scripts/onekeys-hook.sh`

- [ ] **Step 1: Extract the heredoc.** Replace `seed_if_absent`'s inline heredoc with a `print_defaults()` function that `cat`s the `<<'EOF'` block to stdout. Both seeding and OTHER-materialization call it. No behavior change yet.
- [ ] **Step 2: Verify.** `bash -n scripts/onekeys-hook.sh` and `bash tests/hook-test.sh` (existing suite still green — pure refactor).
- [ ] **Step 3: Commit.** `git commit -m "refactor: extract print_defaults emitter"`

### Task 2: Implement reconcile

**Files:** Modify `scripts/onekeys-hook.sh`

- [ ] **Step 1: Add `BASE`, `SIDECAR` path vars** next to `MAP_FILE`: `${HOME}/.claude/onekeyers.base.txt` and `${MAP_FILE}.merge`.
- [ ] **Step 2: Add a `has_conflict_markers FILE` helper** — `grep -q '^<<<<<<<\|^|||||||\|^>>>>>>>' "$FILE"`.
- [ ] **Step 3: Write `reconcile()`** per the algorithm above, using a `mktemp` for OTHER with a cleanup `trap`. Set a script-level `NAG` flag on conflict.
- [ ] **Step 4: Wire it in `main()`** — replace the `seed_if_absent` call with `reconcile`. When `NAG` is set, the emitted JSON's `systemMessage` becomes a conflict notice naming the sidecar (e.g. `onekeys: defaults changed and conflict with your edits — resolve ~/.claude/onekeyers.txt.merge`). The normal expansion path is unchanged when there is no nag.
- [ ] **Step 5: Verify** `bash -n` + `shellcheck scripts/*.sh`. Existing suite green.
- [ ] **Step 6: Commit.** `git commit -m "feat: reconcile mapping with shipped defaults via diff3"`

### Task 3: Tests (tests-after → mutation-validated)

**Files:** Modify `tests/hook-test.sh`

The harness controls `HOME`, so OTHER is the script's real baked-in defaults; the test pre-writes MINE/BASE/sidecar to drive each branch. Add cases:

- [ ] **Step 1: Base seeded on first run** — file absent → after `run "c"`, both `onekeyers.txt` and `onekeyers.base.txt` exist and equal the defaults.
- [ ] **Step 2: Cheap no-op** — pre-write MINE (defaults + a custom `z Foo` line) and BASE = defaults. `run "c"`. Assert MINE unchanged (still has `z Foo`), no sidecar, base unchanged.
- [ ] **Step 3: Clean merge (mainline)** — BASE = defaults with the `t` line removed; MINE = that same BASE plus `z Foo`. OTHER (real defaults) re-adds `t`. `run "c"`. Assert MINE now has **both** `t /autoname` and `z Foo`; base advanced to current defaults; no sidecar.
- [ ] **Step 4: Conflict → sidecar (option b)** — BASE has `w BASEW`, MINE has `w MINEW`, all differ from the real default `w What do you think?`. `run "c"`. Assert: sidecar exists and contains a `|||||||` base section showing `BASEW` (base-included requirement); MINE still has `MINEW` (untouched); base NOT advanced; output `systemMessage` names the sidecar.
- [ ] **Step 5: Resolution promotion** — pre-place a marker-free `onekeyers.txt.merge`, BASE ≠ defaults. `run "c"`. Assert sidecar content promoted to MINE; base advanced; sidecar gone.
- [ ] **Step 6: Pending conflict is silent** — pre-place a sidecar that still has markers. `run "c"`. Assert MINE untouched, sidecar untouched, no nag.
- [ ] **Step 7: Migration (base absent)** — MINE present (custom content), BASE absent. `run "c"`. Assert base created = defaults, MINE untouched, no merge, no sidecar.
- [ ] **Step 8: Run suite.** `bash tests/hook-test.sh` all green.
- [ ] **Step 9: Mutation-validate** every new assertion. Use `"$TMPDIR"` (NOT `/tmp`, which is read-only under the sandbox) for any script backup. For each new check, introduce one deliberate fault in `reconcile` (e.g. don't write base; advance base on conflict; skip the marker check; write MINE on conflict) and confirm *only* the targeted assertion(s) go red. Restore and reconfirm green.
- [ ] **Step 10: Commit.** `git commit -m "test: cover reconcile seed/merge/conflict/migration paths"`

### Task 4: Documentation

**Files:** Modify `README.md`, `DESIGN.md`, `CLAUDE.md`

- [ ] **Step 1: README** — under "Mapping", document that the file reconciles with shipped defaults on update (not frozen), the `onekeyers.base.txt` base file, the `onekeyers.txt.merge` conflict sidecar workflow, and the new `diff3` dependency.
- [ ] **Step 2: DESIGN.md** — new section "Keeping the mapping current: 3-way reconcile": why a persisted base (conflicts need the ancestor to be legible), why the sidecar instead of in-place markers (the file is typed against live), and the transparent/manual split.
- [ ] **Step 3: CLAUDE.md** — update the seeding note in Layout/Conventions to describe reconcile + the base/sidecar files + `diff3` dependency; keep the "fires on every prompt, no-match path stays cheap" invariant accurate (reconcile is behind the single-char gate).
- [ ] **Step 4: Commit.** `git commit -m "docs: document mapping reconcile, base file, and conflict sidecar"`

### Task 5: Preflight & release

- [ ] Run `/ddaa:preflight` (or `just precommit`) — clean tree, green checks, docs audited.
- [ ] Human runs `just release minor` (new user-facing feature → minor bump). **Not** executed by the agent.

---

## Out of scope / explicitly deferred

- No project-level mapping override (still global-only, per the original YAGNI call).
- No automatic backup/rotation of the live file beyond the base + sidecar.
- No reconstruction of the true historical base for already-installed users — migration adopts the user's current file as authoritative (Task 2, step 3 / algorithm step 3).
